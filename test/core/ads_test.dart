import 'package:convertly/core/config/ad_ids.dart';
import 'package:convertly/core/services/ads_service.dart';
import 'package:convertly/core/widgets/native_ad_tile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    setUp(() => ads = AdsService());

    test('nothing is shown before the SDK has started', () {
      for (int i = 0; i < 10; i++) {
        expect(ads.shouldShowAfterExport(), isFalse);
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

    setUp(() => ads = AdsService());
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
        expect(ads.shouldShowAfterExport(), isFalse);
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
}
