import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ad_ids.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    if (!AdIds.isSupportedPlatform) {
      return;
    }

    final NativeAd ad = NativeAd(
      adUnitId: AdIds.native,
      factoryId: NativeAdTile.factoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
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
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
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
