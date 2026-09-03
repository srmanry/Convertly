import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/banner_ad_view.dart';
import '../controllers/converter_controller.dart';

/// Progress state of an in-flight conversion, with a cancel action.
class ConversionProgressView extends GetView<ConverterController> {
  const ConversionProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimens.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Obx(() {
            final double progress = controller.progress.value;
            return Column(
              children: <Widget>[
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: <Widget>[
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          // FFmpeg cannot report a percentage without a known
                          // duration, so fall back to an indeterminate spinner.
                          value: progress > 0 ? progress : null,
                          strokeWidth: 8,
                        ),
                      ),
                      Text(
                        progress > 0 ? '${(progress * 100).round()}%' : '...',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXl),
                Text(
                  'Converting ${controller.mode.title.toLowerCase()}...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDimens.spaceSm),
                Text(
                  'Please wait. Keep the app open.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: AppDimens.spaceXxl),
          Obx(() {
            final String name = controller.primarySource?.name ?? '';
            if (name.isEmpty) {
              return const SizedBox.shrink();
            }
            return Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
            );
          }),
          const SizedBox(height: AppDimens.spaceXl),
          OutlinedButton.icon(
            onPressed: controller.cancel,
            icon: const Icon(Icons.close_rounded),
            label: const Text('Cancel'),
          ),
          // The one screen where the user has nothing to do but wait, so an
          // ad here costs them nothing. Kept well below Cancel: an ad within
          // reach of the button someone is aiming for is how accidental taps
          // happen, and AdMob treats those as its problem too.
          const SizedBox(height: AppDimens.spaceXxl),
          const BannerAdView(),
        ],
      ),
    );
  }
}
