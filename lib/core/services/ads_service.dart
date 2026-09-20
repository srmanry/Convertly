import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';
import '../constants/app_constants.dart';
import 'storage_service.dart';

/// The only place in the app that talks to AdMob.
///
/// Everything above this deals in plain calls, so the ad network can be
/// swapped or switched off without touching any feature code.
class AdsService {
  AdsService(this._storage);

  /// Where earned ad-free files and the place in the ad cycle are kept, so
  /// closing the app neither throws away a reward nor restarts the cycle.
  final StorageService _storage;

  /// Exports in one round of ads, counted across every tool.
  ///
  /// The first file of a round has no full-screen ad, the second offers a
  /// rewarded ad that also covers the two after it, and the last shows an
  /// interstitial. Both play while the file converts. Then the round starts
  /// again.
  static const int exportsPerCycle = 5;

  /// Which export of the round (counting from one) offers the rewarded ad.
  static const int rewardBeforeExport = 2;

  /// How long a conversion runs before its ad appears.
  ///
  /// Long enough that a tap aimed at Convert cannot land on the ad, short
  /// enough that most conversions are still running when it does.
  static const Duration conversionAdDelay = Duration(milliseconds: 1200);

  /// Files the round's own rewarded ad covers: the one it unlocks and the
  /// ones after it, up to the interstitial.
  ///
  /// Counted across every tool, so Video to Audio, Audio Converter and the
  /// rest all draw from the same allowance.
  static const int adFreeExportsReward = 3;

  /// Files covered by a rewarded ad the user chose to watch from a button.
  ///
  /// These sit outside the round: while they last the round is paused, and
  /// it carries on from the same place once they are used up.
  static const int bonusExportsReward = 4;

  /// Rewarded ads that buy a stretch with no ads at all.
  ///
  /// Two rather than one: a single video for ten quiet minutes would be worth
  /// more than the whole round of ads it replaces.
  static const int adsPerBreak = 2;

  /// How long that stretch lasts.
  static const Duration breakDuration = Duration(minutes: 10);

  /// [breakDuration] as the offer states it, so every screen says the same
  /// thing and changing the length changes the wording with it.
  String get breakDurationLabel => '${breakDuration.inMinutes} minutes';

  /// Rewarded ads watched so far towards the next stretch, from zero to
  /// [adsPerBreak] minus one.
  final ValueNotifier<int> adsWatchedTowardBreak = ValueNotifier<int>(0);

  /// When the current stretch ends, or null when there is none.
  ///
  /// A listenable so the settings row can count it down and the banners can
  /// come back the moment it runs out.
  final ValueNotifier<DateTime?> breakEndsAt = ValueNotifier<DateTime?>(null);

  Timer? _breakTimer;

  /// How much of the stretch is left, zero when it is over or never started.
  Duration get breakRemaining {
    final DateTime? endsAt = breakEndsAt.value;
    if (endsAt == null) {
      return Duration.zero;
    }
    final Duration left = endsAt.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Whether the earned stretch is running right now.
  bool get isOnAdFreeBreak => breakRemaining > Duration.zero;

  /// Whether a rewarded ad can be offered for the stretch.
  bool get canOfferBreak => _initialised && _rewarded != null;

  /// Whether ads are currently switched off.
  ///
  /// Exposed as a listenable so the banner and the in-list ad can disappear
  /// the moment it is earned, without either of them polling for it.
  final ValueNotifier<bool> isAdFree = ValueNotifier<bool>(false);

  /// Files left from the round's own rewarded ad. These move the round on.
  int _adFreeExportsLeft = 0;

  /// Files left from a rewarded ad watched by choice. These pause the round.
  int _bonusExportsLeft = 0;

  /// Whether the export that just finished was paid for with the reward.
  ///
  /// Kept apart from the count so the last free file stays ad-free through
  /// its own result screen, instead of the count reaching zero and an
  /// interstitial following it straight away.
  bool _currentExportCovered = false;

  /// How many more files can be exported without ads, from either reward.
  int get adFreeExportsLeft => _adFreeExportsLeft + _bonusExportsLeft;

  /// Exports finished in the current round, from zero up to
  /// [exportsPerCycle] minus one.
  int _exportsInCycle = 0;

  /// Whether this round's rewarded ad has already been offered.
  ///
  /// Kept so a conversion that fails or is cancelled, and is then tried
  /// again, does not ask a second time. Cleared when the round starts over.
  bool _rewardOffered = false;

  /// Whether this round's interstitial has already been shown, for the same
  /// reason.
  bool _interstitialShown = false;

  /// Whether the next export should offer the rewarded ad.
  ///
  /// Only the turn itself: whether an ad is actually loaded is a separate
  /// question, answered by [isRewardDue].
  @visibleForTesting
  bool get isRewardTurn =>
      _exportsInCycle == rewardBeforeExport - 1 &&
      adFreeExportsLeft == 0 &&
      !isOnAdFreeBreak &&
      !_rewardOffered;

  /// Whether the next export should show the interstitial, loaded or not.
  ///
  /// Not when that export is covered by a reward: someone who watched a video
  /// for ad-free files must actually get them.
  @visibleForTesting
  bool get isInterstitialTurn =>
      _exportsInCycle == exportsPerCycle - 1 &&
      adFreeExportsLeft == 0 &&
      !isOnAdFreeBreak &&
      !_interstitialShown;

  /// Reads back what was earned, and where the round was, before the app was
  /// last closed.
  void _restoreAdState() {
    _adFreeExportsLeft = _readCount(StorageKeys.adFreeExportsLeft);
    _bonusExportsLeft = _readCount(StorageKeys.adBonusExportsLeft);
    _restoreAdFreeBreak();

    final int position = _storage.readInt(StorageKeys.adCyclePosition) ?? 0;
    _exportsInCycle = position >= 0 && position < exportsPerCycle
        ? position
        : 0;

    _syncAdFreeState();
  }

  /// Picks the stretch back up where the app left it.
  ///
  /// Minutes keep running while the app is closed: the stretch is ten
  /// minutes of the user's time, not ten minutes of screen time. One that
  /// ran out in the meantime is simply gone.
  void _restoreAdFreeBreak() {
    adsWatchedTowardBreak.value = _readCount(StorageKeys.adBreakProgress).clamp(
      0,
      adsPerBreak - 1,
    );

    final int? endsAtMillis = _storage.readInt(StorageKeys.adBreakEndsAt);
    if (endsAtMillis == null) {
      return;
    }

    final DateTime endsAt = DateTime.fromMillisecondsSinceEpoch(endsAtMillis);
    if (endsAt.isAfter(DateTime.now())) {
      breakEndsAt.value = endsAt;
      _scheduleBreakEnd();
      return;
    }
    unawaited(_storage.remove(StorageKeys.adBreakEndsAt));
  }

  int _readCount(String key) {
    final int stored = _storage.readInt(key) ?? 0;
    return stored < 0 ? 0 : stored;
  }

  /// Starts, or extends, the stretch with no ads.
  ///
  /// Extends from wherever the current one ends rather than from now, so a
  /// second stretch earned early does not throw away the minutes left in the
  /// first.
  void _startAdFreeBreak() {
    final DateTime now = DateTime.now();
    final DateTime from = switch (breakEndsAt.value) {
      final DateTime endsAt when endsAt.isAfter(now) => endsAt,
      _ => now,
    };
    _setBreakEnd(from.add(breakDuration));
  }

  void _setBreakEnd(DateTime? endsAt) {
    breakEndsAt.value = endsAt;
    unawaited(
      endsAt == null
          ? _storage.remove(StorageKeys.adBreakEndsAt)
          : _storage.writeInt(
              StorageKeys.adBreakEndsAt,
              endsAt.millisecondsSinceEpoch,
            ),
    );
    _scheduleBreakEnd();
    _syncAdFreeState();
  }

  /// Brings the ads back the moment the stretch runs out.
  ///
  /// Without this nothing would notice until the next export, and the banner
  /// would stay hidden for a screen that is no longer paid for.
  void _scheduleBreakEnd() {
    _breakTimer?.cancel();
    _breakTimer = null;

    final Duration left = breakRemaining;
    if (left == Duration.zero) {
      return;
    }
    _breakTimer = Timer(left, () {
      _breakTimer = null;
      _setBreakEnd(null);
    });
  }

  /// Counts one watched ad towards the stretch, starting it on the last one.
  ///
  /// Public like the other rewards so the count and the minutes can be tested
  /// without a live ad, which no test can play.
  void grantAdFreeBreakProgress() {
    final int watched = adsWatchedTowardBreak.value + 1;
    if (watched >= adsPerBreak) {
      _setBreakProgress(0);
      _startAdFreeBreak();
      return;
    }
    _setBreakProgress(watched);
  }

  void _setBreakProgress(int watched) {
    adsWatchedTowardBreak.value = watched;
    _persistCount(StorageKeys.adBreakProgress, watched);
  }

  void _syncAdFreeState() {
    final bool active =
        adFreeExportsLeft > 0 || _currentExportCovered || isOnAdFreeBreak;
    if (isAdFree.value != active) {
      isAdFree.value = active;
    }
  }

  void _persistAdFreeExports() {
    _persistCount(StorageKeys.adFreeExportsLeft, _adFreeExportsLeft);
    _persistCount(StorageKeys.adBonusExportsLeft, _bonusExportsLeft);
  }

  void _persistCount(String key, int value) {
    // Written straight away rather than on exit: an app killed by the system
    // gets no chance to save on the way out.
    unawaited(value > 0 ? _storage.writeInt(key, value) : _storage.remove(key));
  }

  bool _initialised = false;
  bool get isReady => _initialised;

  final ValueNotifier<bool> _readiness = ValueNotifier<bool>(false);

  /// Completes once ads may be requested: consent gathered where it is
  /// required and the SDK started. Never completes when they cannot be, so a
  /// banner waiting on it simply stays empty.
  ///
  /// Every ad is requested only after this, so no request goes out ahead of a
  /// consent choice the law requires.
  Future<void> whenReady() {
    if (_readiness.value) {
      return Future<void>.value();
    }
    final Completer<void> ready = Completer<void>();
    void onChange() {
      if (_readiness.value && !ready.isCompleted) {
        _readiness.removeListener(onChange);
        ready.complete();
      }
    }

    _readiness.addListener(onChange);
    return ready.future;
  }

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  /// Whether a rewarded ad is loaded and can be offered right now.
  ///
  /// The button that offers it stays hidden otherwise: an offer that does
  /// nothing when tapped is worse than no offer.
  bool get canOfferReward => _initialised && _rewarded != null;

  /// Starts the SDK. Safe to call more than once.
  Future<void> initialise() async {
    // Restored first and regardless of platform: ad-free files already paid
    // for have to be honoured even if the ad network never comes up.
    _restoreAdState();

    if (_initialised || !AdIds.isSupportedPlatform) {
      return;
    }
    try {
      // Consent comes before the SDK starts: where the law requires a choice,
      // no ad may be requested until it has been made.
      if (!await _gatherConsent()) {
        return;
      }
      // A slow or unresponsive network must not hold this open indefinitely:
      // nothing awaits this call, but it still runs on the same isolate as
      // everything else, so a hang here can still stall the app around it.
      await MobileAds.instance.initialize().timeout(
        const Duration(seconds: 10),
      );
      _initialised = true;
      _readiness.value = true;
      unawaited(_loadInterstitial());
      unawaited(_loadRewarded());
    } catch (error) {
      // A network failure or timeout at startup must not stop the app
      // opening; ads simply stay absent for this run.
      _initialised = false;
    }
  }

  /// Whether the user has to be able to reopen their ad-privacy choices.
  ///
  /// True only where the law asks for it (the EEA, the UK, Switzerland), so
  /// the settings entry appears exactly there and nowhere else.
  final ValueNotifier<bool> privacyOptionsRequired = ValueNotifier<bool>(false);

  /// Asks Google's consent service what is needed, shows the message if one
  /// is due, and reports whether ads may now be requested.
  ///
  /// A failure at any step (no network on a first launch, no message set up
  /// yet) leaves ads off for this run rather than guessing: requesting ads
  /// without a needed consent is the one thing that must not happen.
  Future<bool> _gatherConsent() async {
    try {
      final Completer<void> updated = Completer<void>();
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () {
          if (!updated.isCompleted) {
            updated.complete();
          }
        },
        (FormError error) {
          if (!updated.isCompleted) {
            updated.complete();
          }
        },
      );
      await updated.future.timeout(const Duration(seconds: 10));

      // Shows the message only when one is required and not yet answered. It
      // waits for the user, so it is deliberately not given a timeout.
      await ConsentForm.loadAndShowConsentFormIfRequired((FormError? error) {});
    } catch (error) {
      // Fall through to what is already known from an earlier launch.
    }

    try {
      final PrivacyOptionsRequirementStatus status = await ConsentInformation
          .instance
          .getPrivacyOptionsRequirementStatus();
      privacyOptionsRequired.value =
          status == PrivacyOptionsRequirementStatus.required;
      return await ConsentInformation.instance.canRequestAds();
    } catch (error) {
      return false;
    }
  }

  /// Reopens the consent message so a choice can be changed.
  Future<void> showPrivacyOptions() async {
    try {
      await ConsentForm.showPrivacyOptionsForm((FormError? error) {});
    } catch (error) {
      // Nothing to show; the entry point only offers itself where it can work.
    }
  }

  /// Whether the export about to start should offer the rewarded ad.
  ///
  /// False whenever no ad is loaded, and the export goes ahead either way.
  bool get isRewardDue {
    if (!isRewardTurn) {
      return false;
    }
    if (!canOfferReward) {
      unawaited(_loadRewarded());
      return false;
    }
    return true;
  }

  /// Notes that this round's rewarded ad was offered, whatever the answer.
  void markRewardOffered() => _rewardOffered = true;

  /// Records that an export finished.
  ///
  /// Separate from the decision so a screen can ask whether an ad is coming
  /// without that question itself counting as an export. Uses up one earned
  /// ad-free file when there is one, and moves the round along.
  void recordExport() {
    // The stretch with no ads sits outside the round entirely: it neither
    // spends an earned file nor moves the round on, so the round resumes
    // exactly where it was once the minutes run out.
    if (isOnAdFreeBreak) {
      _currentExportCovered = true;
      _syncAdFreeState();
      return;
    }

    // A file from a reward watched by choice sits outside the round: no ad,
    // and the round does not move, so it picks up where it left off.
    if (_bonusExportsLeft > 0) {
      _bonusExportsLeft--;
      _persistAdFreeExports();
      _currentExportCovered = true;
      _syncAdFreeState();
      return;
    }

    _currentExportCovered = _adFreeExportsLeft > 0;
    if (_currentExportCovered) {
      _adFreeExportsLeft--;
      _persistAdFreeExports();
    }

    _exportsInCycle++;
    if (_exportsInCycle >= exportsPerCycle) {
      _exportsInCycle = 0;
      _rewardOffered = false;
      _interstitialShown = false;
    }
    unawaited(_storage.writeInt(StorageKeys.adCyclePosition, _exportsInCycle));

    _syncAdFreeState();
  }

  /// Marks the export as behind the user, once its result screen is closed.
  ///
  /// Until then the last ad-free file keeps ads away; after it, ads return
  /// for the next file.
  void finishExport() {
    _currentExportCovered = false;
    _syncAdFreeState();
  }

  /// Whether the export about to start should show the interstitial.
  bool get isInterstitialDue =>
      _initialised && _interstitial != null && isInterstitialTurn;

  /// Shows a full-screen ad if one is loaded and it is its turn.
  ///
  /// Returns whether one was shown. The next is loaded as soon as this one is
  /// dismissed, so it is ready well before it is next allowed.
  Future<bool> showInterstitial() async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null || !isInterstitialDue) {
      return false;
    }

    _interstitial = null;
    _interstitialShown = true;

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (InterstitialAd ad) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
      onAdFailedToShowFullScreenContent: (InterstitialAd ad, AdError error) {
        ad.dispose();
        unawaited(_loadInterstitial());
      },
    );

    await ad.show();
    return true;
  }

  /// Adds [adFreeExportsReward] ad-free files that move the round on.
  ///
  /// Stacks rather than resets, so watching a second ad adds to what is left
  /// of the first instead of throwing it away.
  void grantAdFreeExports() {
    _adFreeExportsLeft += adFreeExportsReward;
    _persistAdFreeExports();
    _syncAdFreeState();
  }

  /// Adds [bonusExportsReward] ad-free files that pause the round.
  void grantBonusExports() {
    _bonusExportsLeft += bonusExportsReward;
    _persistAdFreeExports();
    _syncAdFreeState();
  }

  /// Plays the round's rewarded ad, the one that unlocks its second file.
  ///
  /// Returns whether the reward was earned. Closing the ad early earns
  /// nothing, which is the network's rule, not ours.
  Future<bool> watchForAdFreeExports() => _watchRewarded(grantAdFreeExports);

  /// Plays a rewarded ad the user asked for from a button.
  Future<bool> watchForBonusExports() => _watchRewarded(grantBonusExports);

  /// Plays a rewarded ad towards the stretch with no ads.
  ///
  /// Every [adsPerBreak] of these starts the stretch; the ones before it only
  /// move the count along. Returns whether the reward was earned.
  Future<bool> watchForAdFreeBreak() =>
      _watchRewarded(grantAdFreeBreakProgress);

  Future<bool> _watchRewarded(void Function() grant) async {
    final RewardedAd? ad = _rewarded;
    if (ad == null) {
      return false;
    }

    _rewarded = null;
    bool earned = false;

    // show() returns as soon as the ad is on screen, long before the user has
    // watched it, so the answer has to wait for the ad to be closed.
    final Completer<bool> closed = Completer<bool>();

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!closed.isCompleted) {
          closed.complete(earned);
        }
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        unawaited(_loadRewarded());
        if (!closed.isCompleted) {
          closed.complete(false);
        }
      },
    );

    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        earned = true;
        grant();
      },
    );

    return closed.future;
  }

  Future<void> _loadRewarded() async {
    if (_loadingRewarded || _rewarded != null || !_initialised) {
      return;
    }
    _loadingRewarded = true;

    await RewardedAd.load(
      adUnitId: AdIds.rewarded,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          _rewarded = ad;
          _loadingRewarded = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          _rewarded = null;
          _loadingRewarded = false;
        },
      ),
    );
  }

  Future<void> _loadInterstitial() async {
    if (_loadingInterstitial || _interstitial != null || !_initialised) {
      return;
    }
    _loadingInterstitial = true;

    await InterstitialAd.load(
      adUnitId: AdIds.interstitial,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (InterstitialAd ad) {
          _interstitial = ad;
          _loadingInterstitial = false;
        },
        onAdFailedToLoad: (LoadAdError error) {
          // No fill or no network. Nothing is retried on a timer: the next
          // attempt comes with the next dismissal or the next app start.
          _interstitial = null;
          _loadingInterstitial = false;
        },
      ),
    );
  }

  void dispose() {
    _breakTimer?.cancel();
    _breakTimer = null;
    adsWatchedTowardBreak.dispose();
    breakEndsAt.dispose();
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
    isAdFree.dispose();
    privacyOptionsRequired.dispose();
    _readiness.dispose();
  }
}
