import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_dimens.dart';
import '../services/ads_service.dart';

/// Offers [AdsService.bonusExportsReward] ad-free files in exchange for
/// watching one ad, outside the usual round of ads.
///
/// Shows nothing when no rewarded ad is loaded: an offer that does nothing
/// when tapped is worse than no offer at all.
class AdFreeButton extends StatefulWidget {
  const AdFreeButton({super.key});

  @override
  State<AdFreeButton> createState() => _AdFreeButtonState();
}

class _AdFreeButtonState extends State<AdFreeButton> {
  bool _watching = false;

  Future<void> _watch(AdsService ads) async {
    setState(() => _watching = true);
    await ads.watchForBonusExports();
    if (mounted) {
      setState(() => _watching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<AdsService>()) {
      return const SizedBox.shrink();
    }
    final AdsService ads = Get.find<AdsService>();

    return ValueListenableBuilder<bool>(
      valueListenable: ads.isAdFree,
      builder: (BuildContext context, bool isAdFree, _) {
        if (isAdFree) {
          return _RemainingNotice(filesLeft: ads.adFreeExportsLeft);
        }
        if (!ads.canOfferReward) {
          return const SizedBox.shrink();
        }

        return OutlinedButton.icon(
          onPressed: _watching ? null : () => _watch(ads),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: const Text(
            'Watch an ad for '
            '${AdsService.bonusExportsReward} files without ads',
          ),
        );
      },
    );
  }
}

/// How many ad-free files are left, once they have been earned.
class _RemainingNotice extends StatelessWidget {
  const _RemainingNotice({required this.filesLeft});

  final int filesLeft;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: <Widget>[
        Icon(
          Icons.check_circle_rounded,
          size: AppDimens.iconSm,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(switch (filesLeft) {
            0 => 'No ads for this file.',
            1 => 'No ads for your next file.',
            _ => 'No ads for your next $filesLeft files.',
          }, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
