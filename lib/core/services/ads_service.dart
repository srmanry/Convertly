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

  /// Where earned quiet time is kept, so closing the app does not throw away
  /// what the user watched an ad for.
  final StorageService _storage;

  /// How long after showing a full-screen ad before another may be shown.
  ///
  /// A converter is used in bursts; an interstitial after every single export
  /// would make the app unusable and breaks AdMob's own guidance on
  /// interrupting a task the user is in the middle of.
  static const Duration interstitialGap = Duration(minutes: 3);

  /// Exports that have to finish before the first full-screen ad appears, so
  /// someone trying the app is not interrupted on their first result.
  static const int exportsBeforeFirstInterstitial = 2;

  /// Quiet time earned by watching a rewarded ad.
  ///
  /// Long enough to finish a batch of conversions in peace, short enough that
  /// it is worth earning again.
  static const Duration adFreeReward = Duration(minutes: 30);

  /// Whether ads are currently switched off, and when that ends.
  ///
  /// Exposed as a listenable so the banner and the in-list ad can disappear
  /// the moment it is earned, without either of them polling for it.
  final ValueNotifier<bool> isAdFree = ValueNotifier<bool>(false);

  DateTime? _adFreeUntil;
  Timer? _adFreeTimer;

  /// How much quiet time is left, or null when ads are running.
  Duration? get adFreeRemaining {
    _syncAdFreeState();
    final DateTime? until = _adFreeUntil;
    if (until == null) {
      return null;
    }
    final Duration left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
  }

  /// Reads back time earned before the app was last closed.
  void _restoreAdFreeTime() {
    final String? stored = _storage.readString(StorageKeys.adFreeUntil);
    if (stored == null) {
      return;
    }
    final DateTime? until = DateTime.tryParse(stored);
    if (until == null) {
      return;
    }
    _adFreeUntil = until;
    _syncAdFreeState();
  }

  /// Brings the flag in line with the clock.
  ///
  /// The timer below flips it while the app is open, but a device that slept
  /// or an app that was killed cannot be relied on to have fired it. The
  /// deadline is the truth; the timer only makes the change visible promptly.
  void _syncAdFreeState() {
    final DateTime? until = _adFreeUntil;
    final bool active = until != null && until.isAfter(DateTime.now());

    if (!active && until != null) {
      _adFreeUntil = null;
      unawaited(_storage.remove(StorageKeys.adFreeUntil));
    }
    if (isAdFree.value != active) {
      isAdFree.value = active;
    }
  }

  bool _initialised = false;
  bool get isReady => _initialised;

  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;

  RewardedAd? _rewarded;
  bool _loadingRewarded = false;

  /// Whether a rewarded ad is loaded and can be offered right now.
  ///
  /// The button that offers it stays hidden otherwise: an offer that does
  /// nothing when tapped is worse than no offer.
  bool get canOfferReward => _initialised && _rewarded != null;

  DateTime? _lastShown;
  int _completedExports = 0;

  /// Starts the SDK. Safe to call more than once.
  Future<void> initialise() async {
    // Restored first and regardless of platform: quiet time already paid for
    // has to be honoured even if the ad network never comes up.
    _restoreAdFreeTime();

    if (_initialised || !AdIds.isSupportedPlatform) {
      return;
    }
    try {
      await MobileAds.instance.initialize();
      _initialised = true;
      unawaited(_loadInterstitial());
      unawaited(_loadRewarded());
    } catch (error) {
      // A network failure at startup must not stop the app opening; ads
      // simply stay absent for this run.
      _initialised = false;
    }
  }

  /// Records that an export finished.
  ///
  /// Separate from the decision so a screen can ask whether an ad is coming
  /// without that question itself counting as an export.
  void recordExport() => _completedExports++;

  /// Whether a full-screen ad is due right now.
  ///
  /// Read by the result screen as well as by the code that shows the ad, so
  /// what the screen offers matches what is about to happen.
  bool get isInterstitialDue {
    _syncAdFreeState();
    return _canShowInterstitial();
  }

  bool _canShowInterstitial() {
    if (!_initialised || _interstitial == null) {
      return false;
    }
    // Someone who paid for quiet with their attention must actually get it;
    // an interstitial slipping through here is the fastest way to make the
    // reward feel like a trick.
    if (isAdFree.value) {
      return false;
    }
    if (_completedExports < exportsBeforeFirstInterstitial) {
      return false;
    }
    final DateTime? last = _lastShown;
    return last == null || DateTime.now().difference(last) >= interstitialGap;
  }

  /// Shows a full-screen ad if one is loaded and enough time has passed.
  ///
  /// Returns whether one was shown. The next is loaded as soon as this one is
  /// dismissed, so it is ready well before it is next allowed.
  Future<bool> showInterstitial() async {
    final InterstitialAd? ad = _interstitial;
    if (ad == null || !_canShowInterstitial()) {
      return false;
    }

    _interstitial = null;
    _lastShown = DateTime.now();

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

  /// Turns ads off for [adFreeReward], starting now.
  ///
  /// Stacks rather than resets, so watching a second ad extends the quiet
  /// time instead of throwing away what is left of the first.
  void grantAdFreeTime() {
    final DateTime now = DateTime.now();
    final DateTime from = _adFreeUntil ?? now;
    final DateTime base = from.isAfter(now) ? from : now;
    _adFreeUntil = base.add(adFreeReward);
    isAdFree.value = true;

    // Written straight away rather than on exit: an app killed by the system
    // gets no chance to save on the way out.
    unawaited(
      _storage.writeString(
        StorageKeys.adFreeUntil,
        _adFreeUntil!.toIso8601String(),
      ),
    );

    _adFreeTimer?.cancel();
    _adFreeTimer = Timer(_adFreeUntil!.difference(now), _syncAdFreeState);
  }

  /// Plays a rewarded ad and grants quiet time if it is watched through.
  ///
  /// Returns whether the reward was earned. Closing the ad early earns
  /// nothing, which is the network's rule, not ours.
  Future<bool> watchForAdFreeTime() async {
    final RewardedAd? ad = _rewarded;
    if (ad == null) {
      return false;
    }

    _rewarded = null;
    bool earned = false;

    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        ad.dispose();
        unawaited(_loadRewarded());
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        ad.dispose();
        unawaited(_loadRewarded());
      },
    );

    await ad.show(
      onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
        earned = true;
        grantAdFreeTime();
      },
    );

    return earned;
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
    _adFreeTimer?.cancel();
    _adFreeTimer = null;
    _interstitial?.dispose();
    _interstitial = null;
    _rewarded?.dispose();
    _rewarded = null;
    isAdFree.dispose();
  }
}
