import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../controllers/audio_player_controller.dart';

class AudioPlayerPage extends GetView<AudioPlayerController> {
  const AudioPlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Now Playing')),
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
                  title: 'Cannot play this file',
                  message: controller.errorMessage.value,
                  action: FilledButton(
                    onPressed: Get.back<void>,
                    child: const Text('Go Back'),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.all(AppDimens.pagePadding),
                child: Column(
                  children: <Widget>[
                    const Spacer(),
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        size: 72,
                        color: colors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXl),
                    Text(
                      controller.title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    _ProgressBar(controller: controller),
                    const SizedBox(height: AppDimens.spaceLg),
                    _TransportControls(controller: controller),
                    const SizedBox(height: AppDimens.spaceXl),
                    _SpeedSelector(controller: controller),
                    const SizedBox(height: AppDimens.spaceLg),
                    _VolumeSlider(controller: controller),
                    const Spacer(),
                  ],
                ),
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        IconButton(
          tooltip: 'Back 10 seconds',
          iconSize: AppDimens.iconLg,
          onPressed: () => controller.skip(const Duration(seconds: -10)),
          icon: const Icon(Icons.replay_10_rounded),
        ),
        const SizedBox(width: AppDimens.spaceLg),
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
        const SizedBox(width: AppDimens.spaceLg),
        IconButton(
          tooltip: 'Forward 10 seconds',
          iconSize: AppDimens.iconLg,
          onPressed: () => controller.skip(const Duration(seconds: 10)),
          icon: const Icon(Icons.forward_10_rounded),
        ),
      ],
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

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider({required this.controller});

  final AudioPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: <Widget>[
          const Icon(Icons.volume_down_rounded),
          Expanded(
            child: Slider(
              value: controller.volume.value,
              onChanged: controller.setVolume,
            ),
          ),
          const Icon(Icons.volume_up_rounded),
        ],
      ),
    );
  }
}
