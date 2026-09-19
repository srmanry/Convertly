import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';
import '../services/ads_service.dart';
import 'ad_free_gate.dart';

/// A banner that takes up no room until it has something to show.
///
/// An empty reserved strip on every screen is worse than no ad at all, so the
/// widget stays zero-height while loading and if the load fails.
class BannerAdView extends StatefulWidget {
  const BannerAdView({
    super.key,
    this.width,
    this.padding = EdgeInsets.zero,
    this.includeBottomSafeArea = false,
  });

  /// Width available at this placement. Inline placements pass their list
  /// width so the platform ad cannot overflow a padded content column.
  final int? width;

  /// Space that appears only when the ad has actually loaded.
  final EdgeInsetsGeometry padding;

  /// Whether this banner itself must stay above the system navigation area.
  ///
  /// Inline banners and banners above the app's own bottom dock already have
  /// a safe parent. A standalone [Scaffold.bottomNavigationBar] does not.
  final bool includeBottomSafeArea;

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
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
    // Needs the screen width, which is only available once there is a
    // MediaQuery, so this cannot happen in initState.
    if (_ad == null) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    if (_loading || !_active || !AdIds.isSupportedPlatform) {
      return;
    }
    _loading = true;

    // Read while still inside didChangeDependencies. Looking up MediaQuery
    // after an await registers a dependency outside the build phase, which
    // can leave a stale dependent behind when this subtree is torn down.
    final int width =
        widget.width ?? MediaQuery.sizeOf(context).width.truncate();

    try {
      // No request goes out before consent has been settled and the SDK is up.
      if (Get.isRegistered<AdsService>()) {
        await Get.find<AdsService>().whenReady();
        if (!mounted || !_active) {
          return;
        }
      }

      // Sized to the device rather than a fixed 320x50, so the banner fills
      // the width properly on a phone and does not look stranded on a tablet.
      final AdSize? size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
        width,
      );
      if (size == null || !mounted || !_active) {
        return;
      }

      late final BannerAd ad;
      ad = BannerAd(
        size: size,
        adUnitId: AdIds.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (Ad loadedAd) {
            if (!mounted || !_active || !identical(_ad, ad)) {
              loadedAd.dispose();
              return;
            }
            setState(() => _loaded = true);
          },
          onAdFailedToLoad: (Ad failedAd, LoadAdError error) {
            // No fill is normal, especially on a new account. The strip stays
            // collapsed rather than showing a blank box.
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
    final BannerAd? ad = _ad;
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
    final BannerAd? ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    final Widget banner = SizedBox(
      width: ad.size.width.toDouble(),
      height: ad.size.height.toDouble(),
      child: AdWidget(ad: ad),
    );

    return AdFreeGate(
      child: Padding(
        padding: widget.padding,
        child: widget.includeBottomSafeArea
            ? SafeArea(top: false, child: banner)
            : banner,
      ),
    );
  }
}
