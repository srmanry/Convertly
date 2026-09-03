import 'package:convertly/core/config/ad_ids.dart';
import 'package:convertly/core/services/ads_service.dart';
import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/core/widgets/native_ad_tile.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StorageService storage;

  /// A service backed by real preferences, so what survives an app restart is
  /// tested rather than assumed.
  Future<AdsService> newService() async {
    storage = StorageService(await SharedPreferences.getInstance());
    return AdsService(storage);
  }

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('AdIds', () {
    test('a test build never serves a live unit', () {
      // Clicking a live ad on your own device is what gets an account pulled,
      // so this must not depend on remembering to switch anything.
      expect(AdIds.isUsingTestAds, isTrue);
      expect(AdIds.banner, startsWith('ca-app-pub-3940256099942544/'));
      expect(AdIds.interstitial, startsWith('ca-app-pub-3940256099942544/'));
    });

    test('units are unit ids, not app ids', () {
      // The tilde form is the App ID and belongs in the manifest; passing one
      // here fails to load with no obvious reason why.
      expect(AdIds.banner, contains('/'));
      expect(AdIds.banner, isNot(contains('~')));
      expect(AdIds.interstitial, contains('/'));
      expect(AdIds.interstitial, isNot(contains('~')));
    });

    test('the banner and the interstitial are different units', () {
      expect(AdIds.banner, isNot(AdIds.interstitial));
    });
  });

  group('AdsService pacing', () {
    late AdsService ads;

    setUp(() async => ads = await newService());

    test('nothing is shown before the SDK has started', () {
      for (int i = 0; i < 10; i++) {
        ads.recordExport();
        expect(ads.isInterstitialDue, isFalse);
      }
    });

    test('the first exports are never interrupted', () {
      // Someone trying the app has to reach their file without a full-screen
      // ad in the way.
      expect(AdsService.exportsBeforeFirstInterstitial, greaterThan(1));
    });

    test('there is a real gap between full-screen ads', () {
      expect(
        AdsService.interstitialGap,
        greaterThanOrEqualTo(const Duration(minutes: 1)),
      );
    });

    test('an unstarted service shows nothing when asked to', () async {
      expect(await ads.showInterstitial(), isFalse);
    });

    test('disposing an unstarted service is harmless', () {
      expect(ads.dispose, returnsNormally);
    });
  });

  group('where ads fall in a list', () {
    /// Positions an ad follows, for a list of [itemCount] real rows.
    List<int> slotsIn(int itemCount) => <int>[
      for (int i = 0; i < itemCount; i++)
        if (AdSlots.showsAfter(i, itemCount)) i,
    ];

    test('a short list carries no ads at all', () {
      // Two files and an ad between them would read as an ad screen.
      for (int count = 0; count <= AdSlots.firstSlotAfter; count++) {
        expect(slotsIn(count), isEmpty, reason: '$count items');
      }
    });

    test('the first ad waits until a few files are past', () {
      expect(slotsIn(12).first, AdSlots.firstSlotAfter - 1);
    });

    test('ads are spaced evenly after that', () {
      final List<int> slots = slotsIn(40);

      for (int i = 1; i < slots.length; i++) {
        expect(slots[i] - slots[i - 1], AdSlots.everyNItems);
      }
    });

    test('no ad is placed below the last row', () {
      // The screen already has a banner pinned at the bottom; an ad directly
      // above it would put two together.
      for (int count = 1; count < 40; count++) {
        expect(
          AdSlots.showsAfter(count - 1, count),
          isFalse,
          reason: 'last row of $count',
        );
      }
    });

    test('ads stay a small share of a long list', () {
      final int adCount = slotsIn(60).length;

      expect(adCount / 60, lessThan(0.2));
    });

    test('the spacing is wide enough to read as a list, not an ad feed', () {
      expect(AdSlots.everyNItems, greaterThanOrEqualTo(4));
    });
  });

  group('earned quiet time', () {
    late AdsService ads;

    setUp(() async => ads = await newService());
    tearDown(() => ads.dispose());

    test('ads run until some quiet time is earned', () {
      expect(ads.isAdFree.value, isFalse);
      expect(ads.adFreeRemaining, isNull);
    });

    test('watching one ad switches ads off', () {
      ads.grantAdFreeTime();

      expect(ads.isAdFree.value, isTrue);
      expect(ads.adFreeRemaining, isNotNull);
      expect(
        ads.adFreeRemaining!.inSeconds,
        closeTo(AdsService.adFreeReward.inSeconds, 2),
      );
    });

    test('no full-screen ad slips through the quiet time', () {
      // The whole point of the reward. One interstitial getting past this
      // makes the offer feel like a trick.
      ads.grantAdFreeTime();

      for (int i = 0; i < 10; i++) {
        ads.recordExport();
        expect(ads.isInterstitialDue, isFalse);
      }
    });

    test('a second ad extends the time rather than restarting it', () {
      ads.grantAdFreeTime();
      final Duration afterFirst = ads.adFreeRemaining!;

      ads.grantAdFreeTime();

      expect(
        ads.adFreeRemaining!,
        greaterThan(
          afterFirst + AdsService.adFreeReward - const Duration(seconds: 3),
        ),
      );
    });

    test('the banner and the list ad watch the same switch', () {
      // One flag drives every placement, so quiet time cannot be partial.
      final List<bool> seen = <bool>[];
      ads.isAdFree.addListener(() => seen.add(ads.isAdFree.value));

      ads.grantAdFreeTime();

      expect(seen, <bool>[true]);
    });

    test('the reward is worth earning but not permanent', () {
      expect(
        AdsService.adFreeReward,
        greaterThanOrEqualTo(const Duration(minutes: 10)),
      );
      expect(
        AdsService.adFreeReward,
        lessThanOrEqualTo(const Duration(hours: 2)),
      );
    });

    test('nothing is offered before an ad is loaded', () {
      expect(ads.canOfferReward, isFalse);
    });

    test('asking to watch with nothing loaded earns nothing', () async {
      expect(await ads.watchForAdFreeTime(), isFalse);
      expect(ads.isAdFree.value, isFalse);
    });
  });

  group('counting an export is separate from deciding on an ad', () {
    test('asking whether an ad is due does not count as an export', () async {
      final AdsService ads = await newService();
      addTearDown(ads.dispose);

      // The result screen asks this on every completion. If asking counted,
      // merely looking at the screen would bring the next ad closer.
      for (int i = 0; i < 20; i++) {
        expect(ads.isInterstitialDue, isFalse);
      }

      ads.recordExport();
      expect(ads.isInterstitialDue, isFalse);
    });
  });

  group('quiet time survives the app closing', () {
    test('time earned is still there after a restart', () async {
      final AdsService first = await newService();
      first.grantAdFreeTime();
      // Whatever the plugin queued has to reach storage before the restart.
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      // A fresh service is what the app builds when it is opened again.
      final AdsService second = await newService();
      addTearDown(second.dispose);
      await second.initialise();

      expect(second.isAdFree.value, isTrue);
      expect(second.adFreeRemaining, isNotNull);
    });

    test('no full-screen ad slips through after a restart either', () async {
      final AdsService first = await newService();
      first.grantAdFreeTime();
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final AdsService second = await newService();
      addTearDown(second.dispose);
      await second.initialise();

      second.recordExport();
      second.recordExport();
      second.recordExport();
      expect(second.isInterstitialDue, isFalse);
    });

    test('time that has already run out is not restored', () async {
      // Stored deadlines are absolute, so a long gap between sessions must
      // expire the reward rather than hand it back.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_free_until': DateTime.now()
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
      });

      final AdsService ads = await newService();
      addTearDown(ads.dispose);
      await ads.initialise();

      expect(ads.isAdFree.value, isFalse);
      expect(ads.adFreeRemaining, isNull);
    });

    test('a corrupt stored value is ignored rather than crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_free_until': 'not-a-date',
      });

      final AdsService ads = await newService();
      addTearDown(ads.dispose);

      await expectLater(ads.initialise(), completes);
      expect(ads.isAdFree.value, isFalse);
    });

    test('the flag follows the clock, not the timer', () async {
      final AdsService ads = await newService();
      addTearDown(ads.dispose);
      ads.grantAdFreeTime();

      expect(ads.isAdFree.value, isTrue);

      // A device that slept, or an app the system froze, cannot be relied on
      // to have fired the timer; reading the state has to settle it.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_free_until': DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String(),
      });
      final AdsService reopened = await newService();
      addTearDown(reopened.dispose);
      await reopened.initialise();

      expect(reopened.isAdFree.value, isFalse);
    });
  });
}
