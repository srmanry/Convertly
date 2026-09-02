import 'dart:io';

import 'package:flutter/foundation.dart';

/// The AdMob identifiers the app runs with.
///
/// Android only. iOS is a separate app in AdMob with its own App ID and its
/// own units; until those exist the SDK is never started there, which also
/// keeps it from throwing over the identifier its Info.plist does not carry.
///
/// Debug builds always use Google's test units. Serving live ads to yourself
/// while developing is what gets an AdMob account suspended, so the choice is
/// made here rather than left to whoever is running the app.
abstract final class AdIds {
  /// Paste the real units from AdMob here.
  ///
  /// Format: `ca-app-pub-0000000000000000/0000000000` — a slash, not a tilde.
  /// The tilde form is the App ID and belongs in AndroidManifest.xml.
  static const String _banner = 'ca-app-pub-8003887967193956/5518733136';
  static const String _interstitial = 'ca-app-pub-8003887967193956/4014079774';

  /// Create a "Native advanced" unit in AdMob and paste it here. Until then
  /// the list shows the test unit below, which always fills.
  static const String _native = 'ca-app-pub-8003887967193956/4960224738';

  /// Create a "Rewarded" unit in AdMob and paste it here.
  static const String _rewarded = 'ca-app-pub-8003887967193956/6057789181';

  /// Google's own always-fillable units, safe to click.
  static const String _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitial =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _testNative = 'ca-app-pub-3940256099942544/2247696110';
  static const String _testRewarded = 'ca-app-pub-3940256099942544/5224354917';

  /// True while the app has no real units to serve, which is also true of any
  /// debug build.
  ///
  /// Every unit has to be filled in before any of them go live: a half-filled
  /// config would ship one real placement beside one that requests an empty
  /// id and silently never loads.
  static bool get isUsingTestAds =>
      kDebugMode || _banner.isEmpty || _interstitial.isEmpty;

  static String get banner => isUsingTestAds ? _testBanner : _banner;

  static String get interstitial =>
      isUsingTestAds ? _testInterstitial : _interstitial;

  /// The in-list unit falls back on its own: the banner and interstitial can
  /// go live before a native unit exists, and a missing one must not take the
  /// other two down with it.
  static String get native =>
      isUsingTestAds || _native.isEmpty ? _testNative : _native;

  static String get rewarded =>
      isUsingTestAds || _rewarded.isEmpty ? _testRewarded : _rewarded;

  /// Whether ads run here at all.
  static bool get isSupportedPlatform => Platform.isAndroid;
}
