import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/banner_ad_view.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../controllers/audio_player_controller.dart';
import '../widgets/audio_playback_wave.dart';
import '../../../../core/i18n/translation_keys.dart';

class AudioPlayerPage extends GetView<AudioPlayerController> {
  const AudioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text(K.nowPlaying.tr)),
      // Someone listening is resting, not working, and the strip sits below
      // the transport controls rather than among them.
      bottomNavigationBar: const BannerAdView(includeBottomSafeArea: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Obx(() {
              if (controller.errorMessage.value.isNotEmpty) {
                return EmptyStateView(
                  icon: Icons.music_off_rounded,
                  title: K.cannotPlayFile.tr,
                  message: controller.errorMessage.value,
                  action: FilledButton(
                    onPressed: Get.back<void>,
                    child: Text(K.goBack.tr),
                  ),
                );
              }

              // Scrolls rather than overflows. The speed chips wrap onto a
              // second row on a narrow phone, and with fixed spacers that
              // pushed the column past the bottom of the screen.
              return LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppDimens.pagePadding),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - AppDimens.pagePadding * 2,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Obx(
                            () => AudioPlaybackWave(
                              isPlaying:
                                  controller.isPlaying.value &&
                                  !controller.isLoading.value,
                            ),
                          ),
                          const SizedBox(height: AppDimens.spaceXl),
                          _TrackTitle(title: controller.title),
                          if (controller.queue.length > 1) ...<Widget>[
                            const SizedBox(height: AppDimens.spaceXs),
                            Text(
                              K.trackOf.trParams(<String, String>{
                                'index': '${controller.index.value + 1}',
                                'total': '${controller.queue.length}',
                              }),
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                          const SizedBox(height: AppDimens.spaceXxl),
                          _ProgressBar(controller: controller),
                          const SizedBox(height: AppDimens.spaceLg),
                          _TransportControls(controller: controller),
                          const SizedBox(height: AppDimens.spaceXl),
                          _SpeedSelector(controller: controller),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final double totalMs = controller.duration.value.inMilliseconds
          .toDouble();
      final double positionMs = controller.position.value.inMilliseconds
          .toDouble()
          .clamp(0, totalMs == 0 ? 1 : totalMs);

      return Column(
        children: <Widget>[
          Slider(
            min: 0,
            max: totalMs == 0 ? 1 : totalMs,
            value: positionMs,
            onChanged: totalMs == 0
                ? null
                : (double value) =>
                      controller.seek(Duration(milliseconds: value.round())),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(Formatters.duration(controller.position.value)),
                Text(Formatters.duration(controller.duration.value)),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _TransportControls extends StatelessWidget {
  const _TransportControls({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    // Five controls plus a 72px play button do not fit across a 320px phone.
    // Scale-down shrinks the cluster only where it has to, rather than letting
    // it run off the edge.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Shown only when there is a queue to move through, so a single file
          // does not get two controls that can never do anything.
          if (controller.queue.length > 1)
            Obx(
              () => IconButton(
                tooltip: K.previousTrack.tr,
                iconSize: AppDimens.iconLg,
                onPressed: controller.hasPrevious ? controller.previous : null,
                icon: const Icon(Icons.skip_previous_rounded),
              ),
            ),
          IconButton(
            tooltip: K.backTenSeconds.tr,
            iconSize: AppDimens.iconLg,
            onPressed: () => controller.skip(const Duration(seconds: -10)),
            icon: const Icon(Icons.replay_10_rounded),
          ),
          Obx(
            () => FilledButton(
              onPressed: controller.isLoading.value
                  ? null
                  : controller.togglePlay,
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                minimumSize: const Size.square(72),
              ),
              child: Icon(
                controller.isPlaying.value
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 36,
              ),
            ),
          ),
          IconButton(
            tooltip: K.forwardTenSeconds.tr,
            iconSize: AppDimens.iconLg,
            onPressed: () => controller.skip(const Duration(seconds: 10)),
            icon: const Icon(Icons.forward_10_rounded),
          ),
          if (controller.queue.length > 1)
            Obx(
              () => IconButton(
                tooltip: K.nextTrack.tr,
                iconSize: AppDimens.iconLg,
                onPressed: controller.hasNext ? controller.next : null,
                icon: const Icon(Icons.skip_next_rounded),
              ),
            ),
        ],
      ),
    );
  }
}

/// The track's name, in a space two lines tall whether it needs them or not.
///
/// The column is centred, so a title that wrapped onto a second line pushed
/// the progress bar, the transport controls and the speed chips down by half
/// a line — and moving to a shorter-named track pulled them back up. Stepping
/// through a queue made the whole cluster jump about. Holding the height
/// steady costs one blank line under a short name and keeps everything below
/// it still.
class _TrackTitle extends StatelessWidget {
  const _TrackTitle({required this.title});

  final String title;

  static const int _lines = 2;

  @override
  Widget build(BuildContext context) {
    final TextStyle style =
        Theme.of(context).textTheme.titleMedium ?? const TextStyle();
    // Scaled the way the text itself will be, so the reserved space still
    // fits two lines for someone using a larger font size.
    final double lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? 16) * (style.height ?? 1.3));

    return SizedBox(
      height: lineHeight * _lines,
      child: Center(
        child: Text(
          title,
          textAlign: TextAlign.center,
          maxLines: _lines,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
      ),
    );
  }
}

class _SpeedSelector extends StatelessWidget {
  const _SpeedSelector({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppDimens.spaceSm,
        alignment: WrapAlignment.center,
        children: <Widget>[
          for (final double value in kPlaybackSpeeds)
            ChoiceChip(
              label: Text(
                value == value.roundToDouble()
                    ? '${value.toInt()}x'
                    : '${value}x',
              ),
              selected: controller.speed.value == value,
              onSelected: (bool selected) {
                if (selected) {
                  controller.setSpeed(value);
                }
              },
            ),
        ],
      ),
    );
  }
}
