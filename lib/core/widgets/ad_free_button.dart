import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../constants/app_dimens.dart';
import '../services/ads_service.dart';
import '../utils/formatters.dart';

/// Offers quiet time in exchange for watching one ad.
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
    await ads.watchForAdFreeTime();
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
          return _RemainingNotice(remaining: ads.adFreeRemaining);
        }
        if (!ads.canOfferReward) {
          return const SizedBox.shrink();
        }

        return OutlinedButton.icon(
          onPressed: _watching ? null : () => _watch(ads),
          icon: const Icon(Icons.play_circle_outline_rounded),
          label: Text(
            'Watch an ad for '
            '${_minutes(AdsService.adFreeReward)} without ads',
          ),
        );
      },
    );
  }

  static String _minutes(Duration duration) => '${duration.inMinutes} minutes';
}

/// What is left of the quiet time, once it has been earned.
class _RemainingNotice extends StatelessWidget {
  const _RemainingNotice({required this.remaining});

  final Duration? remaining;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration? left = remaining;

    return Row(
      children: <Widget>[
        Icon(
          Icons.check_circle_rounded,
          size: AppDimens.iconSm,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Expanded(
          child: Text(
            left == null
                ? 'No ads for now.'
                : 'No ads for the next ${Formatters.duration(left)}.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
