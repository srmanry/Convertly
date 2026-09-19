import 'dart:async';

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

    /// Finishes one export the way the converter does.
    void export() {
      ads.recordExport();
      ads.finishExport();
    }

    test('the round is five files with the video on the second', () {
      expect(AdsService.exportsPerCycle, 5);
      expect(AdsService.rewardBeforeExport, 2);
      expect(AdsService.adFreeExportsReward, 3);
    });

    test('the ad waits long enough to dodge the tap on Convert', () {
      expect(
        AdsService.conversionAdDelay,
        greaterThanOrEqualTo(const Duration(milliseconds: 500)),
      );
      expect(
        AdsService.conversionAdDelay,
        lessThanOrEqualTo(const Duration(seconds: 3)),
      );
    });

    test('the first file has no full-screen ad', () {
      expect(ads.isRewardTurn, isFalse);
      expect(ads.isInterstitialTurn, isFalse);
    });

    test('the second file offers the video', () {
      export();

      expect(ads.isRewardTurn, isTrue);
      expect(ads.isInterstitialTurn, isFalse);
    });

    test('without an ad loaded nothing is offered', () {
      export();

      expect(ads.isRewardDue, isFalse);
    });

    test('a watched video covers files two to four, and the fifth shows '
        'the interstitial', () {
      export();

      // Earned while file two converts, before it is counted.
      ads.markRewardOffered();
      ads.grantAdFreeExports();
      for (int file = 2; file <= 4; file++) {
        expect(ads.isRewardTurn, isFalse, reason: 'file $file');
        expect(ads.isInterstitialTurn, isFalse, reason: 'file $file');
        ads.recordExport();
        expect(ads.isAdFree.value, isTrue, reason: 'file $file');
        ads.finishExport();
      }

      expect(ads.isAdFree.value, isFalse);
      expect(ads.isInterstitialTurn, isTrue);
    });

    test('a declined video still converts, and the round carries on', () {
      export();
      ads.markRewardOffered();
      export(); // File two, converted without the reward.

      for (int file = 3; file <= 4; file++) {
        expect(ads.isRewardTurn, isFalse, reason: 'file $file');
        ads.recordExport();
        expect(ads.isAdFree.value, isFalse, reason: 'file $file');
        ads.finishExport();
      }
      expect(ads.isInterstitialTurn, isTrue);
    });

    test('a retry after a failed second file does not ask again', () {
      export();
      ads.markRewardOffered();
      // The conversion failed, so nothing was recorded.

      expect(ads.isRewardTurn, isFalse);
    });

    test('the round starts again after the fifth file', () {
      for (int round = 0; round < 3; round++) {
        export();
        expect(ads.isRewardTurn, isTrue, reason: 'round $round');
        ads.markRewardOffered();
        ads.grantAdFreeExports();

        for (int file = 2; file <= 4; file++) {
          export();
        }

        expect(ads.isInterstitialTurn, isTrue, reason: 'round $round');
        export();
        expect(ads.isInterstitialTurn, isFalse, reason: 'round $round');
        expect(ads.isRewardTurn, isFalse, reason: 'round $round');
      }
    });

    test('the offer comes back in the next round', () {
      export();
      ads.markRewardOffered();
      for (int file = 2; file <= 5; file++) {
        export();
      }

      export();
      expect(ads.isRewardTurn, isTrue);
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

  group('earned ad-free files', () {
    late AdsService ads;

    setUp(() async => ads = await newService());
    tearDown(() => ads.dispose());

    test('ads run until something is earned', () {
      expect(ads.isAdFree.value, isFalse);
      expect(ads.adFreeExportsLeft, 0);
    });

    test('watching one ad earns three files', () {
      ads.grantAdFreeExports();

      expect(ads.isAdFree.value, isTrue);
      expect(ads.adFreeExportsLeft, AdsService.adFreeExportsReward);
      expect(AdsService.adFreeExportsReward, 3);
    });

    test('each finished export uses one file', () {
      ads.grantAdFreeExports();

      ads.recordExport();
      expect(ads.adFreeExportsLeft, 2);
      ads.finishExport();

      ads.recordExport();
      expect(ads.adFreeExportsLeft, 1);
    });

    test('no interstitial on a fifth file covered by the reward', () {
      // Earned from a button just before the end of a round: the fifth file
      // is covered, so its interstitial is skipped.
      for (int file = 1; file <= 4; file++) {
        ads.recordExport();
        ads.finishExport();
      }
      ads.grantAdFreeExports();

      expect(ads.isInterstitialTurn, isFalse);
    });

    test('the last free file stays ad-free until it is finished', () {
      // Otherwise the count reaching zero would let an interstitial follow
      // the very file the reward was meant to cover.
      ads.grantAdFreeExports();
      for (int i = 0; i < AdsService.adFreeExportsReward; i++) {
        ads.recordExport();
        expect(ads.isAdFree.value, isTrue, reason: 'file ${i + 1}');
        expect(ads.isInterstitialDue, isFalse);
        ads.finishExport();
      }

      expect(ads.isAdFree.value, isFalse);
      expect(ads.adFreeExportsLeft, 0);
    });

    test('ads come back for the file after the free ones', () {
      ads.grantAdFreeExports();
      for (int i = 0; i < AdsService.adFreeExportsReward; i++) {
        ads.recordExport();
        ads.finishExport();
      }

      ads.recordExport();
      expect(ads.isAdFree.value, isFalse);
    });

    test('a second ad adds to what is left rather than resetting it', () {
      ads.grantAdFreeExports();
      ads.recordExport();
      ads.finishExport();

      ads.grantAdFreeExports();

      expect(ads.adFreeExportsLeft, 2 + AdsService.adFreeExportsReward);
    });

    test('the banner and the list ad watch the same switch', () {
      // One flag drives every placement, so ad-free files cannot be partial.
      final List<bool> seen = <bool>[];
      ads.isAdFree.addListener(() => seen.add(ads.isAdFree.value));

      ads.grantAdFreeExports();

      expect(seen, <bool>[true]);
    });

    test('nothing is offered before an ad is loaded', () {
      expect(ads.canOfferReward, isFalse);
    });

    test('asking to watch with nothing loaded earns nothing', () async {
      expect(await ads.watchForAdFreeExports(), isFalse);
      expect(ads.isAdFree.value, isFalse);
    });
  });

  group('a video watched by choice', () {
    late AdsService ads;

    setUp(() async => ads = await newService());
    tearDown(() => ads.dispose());

    /// Finishes one export the way the converter does.
    void export() {
      ads.recordExport();
      ads.finishExport();
    }

    test('earns four files without ads', () {
      ads.grantBonusExports();

      expect(AdsService.bonusExportsReward, 4);
      expect(ads.adFreeExportsLeft, 4);
      for (int file = 1; file <= 4; file++) {
        expect(ads.isRewardTurn, isFalse, reason: 'file $file');
        expect(ads.isInterstitialTurn, isFalse, reason: 'file $file');
        ads.recordExport();
        expect(ads.isAdFree.value, isTrue, reason: 'file $file');
        ads.finishExport();
      }
      expect(ads.isAdFree.value, isFalse);
    });

    test('pauses the round and picks it up where it left off', () {
      // One file into the round, so the next would offer the round's video.
      export();
      expect(ads.isRewardTurn, isTrue);

      ads.grantBonusExports();
      for (int file = 1; file <= 4; file++) {
        expect(ads.isRewardTurn, isFalse, reason: 'bonus file $file');
        export();
      }

      // Still the second file of the round.
      expect(ads.isRewardTurn, isTrue);
    });

    test('keeps the interstitial from landing inside the bonus files', () {
      for (int file = 1; file <= 4; file++) {
        export();
      }
      expect(ads.isInterstitialTurn, isTrue);

      ads.grantBonusExports();
      for (int file = 1; file <= 4; file++) {
        expect(ads.isInterstitialTurn, isFalse, reason: 'bonus file $file');
        export();
      }

      // The fifth file of the round, now that the bonus is spent.
      expect(ads.isInterstitialTurn, isTrue);
    });

    test("is used before what is left of the round's own video", () {
      export();
      ads.markRewardOffered();
      ads.grantAdFreeExports();
      export(); // Round file two, covered by the round's video.

      ads.grantBonusExports();
      for (int file = 1; file <= 4; file++) {
        export();
      }

      // Round files three and four are still covered, then the interstitial.
      expect(ads.adFreeExportsLeft, 2);
      export();
      export();
      expect(ads.isInterstitialTurn, isTrue);
    });

    test('survives a restart', () async {
      ads.grantBonusExports();
      export();
      await Future<void>.delayed(Duration.zero);

      final AdsService reopened = await newService();
      addTearDown(reopened.dispose);
      await reopened.initialise();

      expect(reopened.adFreeExportsLeft, 3);
      expect(reopened.isAdFree.value, isTrue);
    });

    test('asking to watch with nothing loaded earns nothing', () async {
      expect(await ads.watchForBonusExports(), isFalse);
      expect(ads.adFreeExportsLeft, 0);
    });
  });

  group('ads wait for consent and the SDK', () {
    test('nothing is ready before the SDK has started', () async {
      final AdsService ads = await newService();
      addTearDown(ads.dispose);
      await ads.initialise();

      bool released = false;
      unawaited(ads.whenReady().then((_) => released = true));
      await Future<void>.delayed(Duration.zero);

      // Where ads never start (here, no Android), a banner waiting on this
      // must simply stay empty rather than request an ad regardless.
      expect(released, isFalse);
      expect(ads.isReady, isFalse);
    });

    test('the ad-privacy entry is off until the law asks for it', () async {
      final AdsService ads = await newService();
      addTearDown(ads.dispose);

      expect(ads.privacyOptionsRequired.value, isFalse);
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

  group('ad-free files survive the app closing', () {
    test('files earned are still there after a restart', () async {
      final AdsService first = await newService();
      first.grantAdFreeExports();
      first.recordExport();
      // Whatever the plugin queued has to reach storage before the restart.
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      // A fresh service is what the app builds when it is opened again.
      final AdsService second = await newService();
      addTearDown(second.dispose);
      await second.initialise();

      expect(second.isAdFree.value, isTrue);
      expect(second.adFreeExportsLeft, AdsService.adFreeExportsReward - 1);
    });

    test('the place in the round is kept after a restart', () async {
      final AdsService first = await newService();
      first.recordExport();
      first.finishExport();
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final AdsService second = await newService();
      addTearDown(second.dispose);
      await second.initialise();

      // Closing the app after the first file must not dodge the video.
      expect(second.isRewardTurn, isTrue);
    });

    test('a stored round position out of range starts a new round', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_cycle_position': 99,
      });

      final AdsService ads = await newService();
      addTearDown(ads.dispose);
      await ads.initialise();

      expect(ads.isRewardTurn, isFalse);
    });

    test('used-up files are not restored', () async {
      final AdsService first = await newService();
      first.grantAdFreeExports();
      for (int i = 0; i < AdsService.adFreeExportsReward; i++) {
        first.recordExport();
        first.finishExport();
      }
      await Future<void>.delayed(Duration.zero);
      first.dispose();

      final AdsService second = await newService();
      addTearDown(second.dispose);
      await second.initialise();

      expect(second.isAdFree.value, isFalse);
      expect(second.adFreeExportsLeft, 0);
    });

    test('a corrupt stored value is ignored rather than crashing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'ads_free_exports_left': -4,
      });

      final AdsService ads = await newService();
      addTearDown(ads.dispose);

      await expectLater(ads.initialise(), completes);
      expect(ads.isAdFree.value, isFalse);
      expect(ads.adFreeExportsLeft, 0);
    });
  });
}
