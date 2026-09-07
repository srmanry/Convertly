import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';
import 'ad_free_gate.dart';

/// A banner that takes up no room until it has something to show.
///
/// An empty reserved strip on every screen is worse than no ad at all, so the
/// widget stays zero-height while loading and if the load fails.
class BannerAdView extends StatefulWidget {
  const BannerAdView({super.key, this.width, this.padding = EdgeInsets.zero});

  /// Width available at this placement. Inline placements pass their list
  /// width so the platform ad cannot overflow a padded content column.
  final int? width;

  /// Space that appears only when the ad has actually loaded.
  final EdgeInsetsGeometry padding;

  @override
  State<BannerAdView> createState() => _BannerAdViewState();
}

class _BannerAdViewState extends State<BannerAdView> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Needs the screen width, which is only available once there is a
    // MediaQuery, so this cannot happen in initState.
    if (_ad == null) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!AdIds.isSupportedPlatform) {
      return;
    }

    final int width =
        widget.width ?? MediaQuery.sizeOf(context).width.truncate();
    // Sized to the device rather than a fixed 320x50, so the banner fills the
    // width properly on a phone and does not look stranded on a tablet.
    final AdSize? size = await AdSize.getLargeAnchoredAdaptiveBannerAdSize(
      width,
    );
    if (size == null || !mounted) {
      return;
    }

    final BannerAd ad = BannerAd(
      size: size,
      adUnitId: AdIds.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // No fill is normal, especially on a new account. The strip stays
          // collapsed rather than showing a blank box.
          ad.dispose();
          if (mounted) {
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
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final BannerAd? ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }

    return AdFreeGate(
      child: Padding(
        padding: widget.padding,
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
