import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';

/// The only place in the app that talks to AdMob.
///
/// Everything above this deals in plain calls, so the ad network can be
/// swapped or switched off without touching any feature code.
class AdsService {
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
    final DateTime? until = _adFreeUntil;
    if (until == null) {
      return null;
    }
    final Duration left = until.difference(DateTime.now());
    return left.isNegative ? null : left;
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

  /// Records that an export finished, and reports whether an ad may follow.
  ///
  /// Kept together so the count and the decision cannot drift apart.
  bool shouldShowAfterExport() {
    _completedExports++;
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
    final DateTime from = _adFreeUntil ?? DateTime.now();
    final DateTime base = from.isAfter(DateTime.now()) ? from : DateTime.now();
    _adFreeUntil = base.add(adFreeReward);
    isAdFree.value = true;

    _adFreeTimer?.cancel();
    _adFreeTimer = Timer(_adFreeUntil!.difference(DateTime.now()), () {
      _adFreeUntil = null;
      isAdFree.value = false;
    });
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
