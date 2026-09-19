import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';
import '../services/ads_service.dart';
import 'ad_free_gate.dart';

/// An ad shaped like a row, for placing among a list of real content.
///
/// Takes up no room until it has loaded, so a list never opens a blank gap
/// where an ad failed to arrive.
class NativeAdTile extends StatefulWidget {
  const NativeAdTile({super.key});

  /// Matches the factory registered in MainActivity. The two are looked up by
  /// this string at runtime, so they have to agree exactly.
  static const String factoryId = 'listTile';

  /// Height the row is given. A native ad has no intrinsic size in Flutter, so
  /// one has to be declared for it.
  static const double tileHeight = 92;

  @override
  State<NativeAdTile> createState() => _NativeAdTileState();
}

class _NativeAdTileState extends State<NativeAdTile> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _loading = false;
  bool _active = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _active = TickerMode.valuesOf(context).enabled;
    if (!_active) {
      _disposeAd();
      return;
    }
    if (_ad == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading || !_active || !AdIds.isSupportedPlatform) {
      return;
    }
    _loading = true;

    try {
      // No request goes out before consent has been settled and the SDK is up.
      if (Get.isRegistered<AdsService>()) {
        await Get.find<AdsService>().whenReady();
        if (!mounted || !_active) {
          return;
        }
      }

      late final NativeAd ad;
      ad = NativeAd(
        adUnitId: AdIds.native,
        factoryId: NativeAdTile.factoryId,
        request: const AdRequest(),
        listener: NativeAdListener(
          onAdLoaded: (Ad loadedAd) {
            if (!mounted || !_active || !identical(_ad, ad)) {
              loadedAd.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
            failedAd.dispose();
            if (mounted && identical(_ad, ad)) {
              setState(() {
                _ad = null;
                _loaded = false;
              });
            }
          },
        ),
      );

      _ad = ad;
      await ad.load();
    } finally {
      _loading = false;
    }
  }

  void _disposeAd() {
    final NativeAd? ad = _ad;
    _ad = null;
    _loaded = false;
    if (ad != null) {
      unawaited(ad.dispose());
    }
  }

  @override
  void dispose() {
    _active = false;
    _disposeAd();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NativeAd? ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return AdFreeGate(
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          height: NativeAdTile.tileHeight,
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}

/// Where ads fall in a list of [itemCount] real rows.
///
/// Spaced out on purpose: an ad every few rows reads as a list with ads in it,
/// while one every other row reads as an ad screen, and AdMob treats crowding
/// as a policy problem rather than a style choice.
abstract final class AdSlots {
  /// Real rows between one ad and the next.
  static const int everyNItems = 6;

  /// Rows shown before the first ad, so a short list has none at all.
  static const int firstSlotAfter = 4;

  /// Whether an ad belongs after the row at [index].
  static bool showsAfter(int index, int itemCount) {
    if (index < firstSlotAfter - 1) {
      return false;
    }
    // Never below the last row: the banner already sits at the bottom of the
    // screen, and two ads together is the crowding this avoids elsewhere.
    if (index >= itemCount - 1) {
      return false;
    }
    return (index - (firstSlotAfter - 1)) % everyNItems == 0;
  }
}
