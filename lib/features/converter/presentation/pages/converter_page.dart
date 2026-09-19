import 'dart:async';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/enums/cleanup_mode.dart';
import '../../../../core/enums/compression_level.dart';
import '../../../../core/enums/export_speed.dart';
import '../../../../core/enums/mix_length_mode.dart';
import '../../../../core/enums/noise_strength.dart';
import '../../../../core/enums/tool_mode.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/empty_state_view.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/entities/mix_track.dart';
import '../../domain/entities/volume_envelope.dart';
import '../../../files/domain/entities/media_file.dart';
import '../controllers/converter_controller.dart';
import '../controllers/mix_preview_controller.dart';
import '../controllers/timeline_preview_controller.dart';
import '../controllers/trim_preview_controller.dart';
import '../controllers/trim_waveform_controller.dart';
import '../widgets/clip_timeline_strip.dart';
import '../widgets/mix_track_list.dart';
import '../widgets/option_chips.dart';
import '../widgets/source_summary_card.dart';
import '../widgets/trim_waveform.dart';
import 'conversion_progress_view.dart';

/// Configuration screen shared by every conversion tool.
class ConverterPage extends GetView<ConverterController> {
  const ConverterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(controller.mode.title)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Obx(() {
              return switch (controller.stage.value) {
                ConverterStage.converting => const ConversionProgressView(),
                ConverterStage.failed => _FailureView(controller: controller),
                _ => _ConfigurationView(controller: controller),
              };
            }),
          ),
        ),
      ),
    );
  }
}

/// Shown when FFmpeg could not produce an output file.
///
/// Only the user-facing message is displayed; the technical log stays in the
/// failure's debug field.
class _FailureView extends StatelessWidget {
  const _FailureView({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => EmptyStateView(
        icon: Icons.error_outline_rounded,
        title: 'Conversion failed',
        message: controller.errorMessage.value.isNotEmpty
            ? controller.errorMessage.value
            : 'Unable to convert this file. Please try another one.',
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextButton(
              onPressed: () =>
                  Get.until((Route<dynamic> route) => route.isFirst),
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationView extends StatelessWidget {
  const _ConfigurationView({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<MediaInfo> sources = controller.sources;

      if (sources.isEmpty) {
        return _EmptySelection(controller: controller);
      }

      final ThemeData theme = Theme.of(context);

      return Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppDimens.pagePadding),
              children: <Widget>[
                if (controller.mode.isMix) ...<Widget>[
                  Text(
                    'Adjust the volume of each track over time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
                if (controller.mode.combinesTracks)
                  MixTrackList(
                    sources: sources,
                    // Copied inside the Obx so a volume change is a read this
                    // builder registers, and the list rebuilds with it.
                    volumes: <double>[
                      for (int i = 0; i < controller.clips.length; i++)
                        controller.clipAt(i).volume,
                    ],
                    starts: <Duration>[
                      for (int i = 0; i < controller.clips.length; i++)
                        controller.startOfTrack(i),
                    ],
                    // Cutting a clip down to the part being used belongs to
                    // the timeline; the mixer layers whole tracks.
                    trimRanges: controller.mode.isTimeline
                        ? <(Duration, Duration)>[
                            for (int i = 0; i < controller.sources.length; i++)
                              controller.trimRangeOf(i),
                          ]
                        : null,
                    onTrimChanged: controller.mode.isTimeline
                        ? controller.setClipTrim
                        : null,
                    onPreviewClip: controller.mode.isTimeline
                        ? (int index) => _previewClip(controller, index)
                        : null,
                    previewingClip: controller.mode.isTimeline
                        ? _previewingClip(controller)
                        : null,
                    previewError: controller.mode.isTimeline
                        ? _clipPreviewError(controller)?.$2
                        : null,
                    previewErrorClip: controller.mode.isTimeline
                        ? _clipPreviewError(controller)?.$1
                        : null,
                    // The two tools show opposite controls: the mixer
                    // balances clips that all start together, the timeline
                    // places clips that each play in turn.
                    onVolumeChanged: controller.mode.isTimeline
                        ? null
                        : controller.setTrackVolume,
                    // Shaping a level over time belongs to the mixer, where
                    // tracks play at once and have to make room for each
                    // other; on the timeline they take turns.
                    envelopes: controller.mode.isMix
                        ? <VolumeEnvelope>[
                            for (int i = 0; i < controller.clips.length; i++)
                              controller.envelopeOf(i),
                          ]
                        : null,
                    onEnvelopeChanged: controller.mode.isMix
                        ? controller.setEnvelope
                        : null,
                    onEnvelopeCleared: controller.mode.isMix
                        ? controller.clearEnvelope
                        : null,
                    playheadOf: controller.mode.isMix
                        ? Get.find<MixPreviewController>().playheadOf
                        : null,
                    onPreviewToggle: controller.mode.isMix
                        ? controller.toggleMixPreview
                        : null,
                    isPreviewPlaying:
                        controller.mode.isMix &&
                        Get.find<MixPreviewController>().isPlaying.value,
                    isPreviewPreparing:
                        controller.mode.isMix &&
                        Get.find<MixPreviewController>().isPreparing.value,
                    showsPositions: controller.mode.isTimeline,
                    onRemove: controller.removeSourceAt,
                    onReorder: controller.reorderSources,
                  )
                else if (controller.mode.picksMultiple)
                  _MergeList(controller: controller)
                else
                  SourceSummaryCard(
                    media: sources.first,
                    onRemove: () => controller.removeSourceAt(0),
                  ),
                if (_offersLibraryPicker(controller)) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceMd),
                  _SourcePickerActions(controller: controller, compact: true),
                ],
                if (controller.mode.picksMultiple &&
                    !_offersLibraryPicker(controller)) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceMd),
                  _PickingProgress(controller: controller),
                  OutlinedButton.icon(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.pickSource,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add more files'),
                  ),
                ],
                if (controller.mode.supportsTrim) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceXl),
                  _TrimSection(controller: controller),
                ],
                if (controller.mode.isTimeline) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceXl),
                  _TimelineSection(controller: controller),
                ],
                if (controller.mode.isMix) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceXl),
                  _MixSection(controller: controller),
                ],
                if (controller.mode.isCleanup) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceXl),
                  _CleanupSection(controller: controller),
                ],
                const SizedBox(height: AppDimens.spaceXl),
                if (controller.mode.isCompression)
                  _CompressionSection(controller: controller)
                else
                  _FormatSection(controller: controller),
                const SizedBox(height: AppDimens.spaceXl),
                _FileNameField(controller: controller),
                Obx(() {
                  final String message = controller.errorMessage.value;
                  if (message.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimens.spaceLg),
                    child: Text(
                      message,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: Obx(
              () => FilledButton.icon(
                onPressed: controller.canConvert ? controller.convert : null,
                icon: Icon(_iconFor(controller.mode)),
                label: Text(_actionLabel(controller)),
              ),
            ),
          ),
        ],
      );
    });
  }
}

/// Plays only the selected part of one clip.
///
/// Reuses the cutter's preview player, which already bounds playback to a
/// range, so hearing a selection here works the same way it does there.
void _previewClip(ConverterController controller, int index) {
  final TrimPreviewController preview = Get.find<TrimPreviewController>();
  final (Duration start, Duration end) range = controller.trimRangeOf(index);

  unawaited(
    preview.toggle(
      source: controller.sources[index].playableSource,
      start: range.$1,
      end: range.$2,
      speed: 1,
      tag: '$index',
    ),
  );
}

/// Which clip the running selection preview belongs to, if any.
int? _previewingClip(ConverterController controller) {
  if (!Get.isRegistered<TrimPreviewController>()) {
    return null;
  }
  final TrimPreviewController preview = Get.find<TrimPreviewController>();
  if (!preview.isPlaying.value) {
    return null;
  }
  return int.tryParse(preview.playingTag.value);
}

/// The failed clip preview, if the last one failed.
(int clip, String message)? _clipPreviewError(ConverterController controller) {
  if (!Get.isRegistered<TrimPreviewController>()) {
    return null;
  }
  final TrimPreviewController preview = Get.find<TrimPreviewController>();
  final int? clip = int.tryParse(preview.errorTag.value);
  if (clip == null || preview.errorMessage.value.isEmpty) {
    return null;
  }
  return (clip, preview.errorMessage.value);
}

/// Label for the export button.
///
/// Says what the tool does. "Convert" is wrong for a cutter or a mixer, which
/// are producing a new track rather than changing the format of an existing
/// one. The button's icon comes from [_iconFor], so the two always agree.
String _actionLabel(ConverterController controller) =>
    switch (controller.mode) {
      ToolMode.videoToAudio => 'Extract Audio',
      ToolMode.audioConvert => 'Convert',
      ToolMode.cut => 'Cut Audio',
      ToolMode.merge => 'Merge Files',
      ToolMode.compress => 'Compress',
      ToolMode.mix => 'Mix Tracks',
      ToolMode.arrange => 'Build Track',
      ToolMode.cleanup => 'Clean Audio',
    };

/// Whether this tool also offers the app's own converted files as input.
///
/// Cleaning up or layering a file the app produced earlier is a normal next
/// step, so those tools get the second picker the cutter already had.
bool _offersLibraryPicker(ConverterController controller) =>
    controller.mode.supportsTrim ||
    controller.mode.isCleanup ||
    controller.mode.combinesTracks;

class _EmptySelection extends StatelessWidget {
  const _EmptySelection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double minHeight = constraints.hasBoundedHeight
            ? math.max(0, constraints.maxHeight - AppDimens.pagePadding * 2)
            : 0;

        return Obx(() {
          final ThemeData theme = Theme.of(context);
          final Color accent = _accentFor(controller.mode);
          final String error = controller.errorMessage.value;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.pagePadding),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  // No card around it: the icon, title and buttons sit
                  // straight on the page.
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimens.spaceXl),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Container(
                            width: 64,
                            height: 64,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _iconFor(controller.mode),
                              color: accent,
                              size: 30,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceLg),
                        Text(
                          controller.mode.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppDimens.spaceSm),
                        Text(
                          controller.mode.description,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (error.isNotEmpty) ...<Widget>[
                          const SizedBox(height: AppDimens.spaceMd),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppDimens.spaceMd),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.errorContainer
                                  .withValues(alpha: 0.48),
                              borderRadius: BorderRadius.circular(
                                AppDimens.radiusMd,
                              ),
                            ),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppDimens.spaceXl),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Divider(
                                color: accent.withValues(alpha: 0.2),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimens.spaceMd,
                              ),
                              child: Text(
                                'CHOOSE A SOURCE',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: accent.withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimens.spaceLg),
                        if (_offersLibraryPicker(controller))
                          _SourcePickerActions(controller: controller)
                        else
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              _PickingProgress(controller: controller),
                              FilledButton.icon(
                                onPressed: controller.isPicking.value
                                    ? null
                                    : controller.pickSource,
                                icon: const Icon(Icons.folder_open_rounded),
                                label: Text(controller.mode.actionLabel),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        });
      },
    );
  }
}

IconData _iconFor(ToolMode mode) => switch (mode) {
  ToolMode.videoToAudio => Icons.movie_creation_rounded,
  ToolMode.audioConvert => Icons.swap_horiz_rounded,
  ToolMode.cut => Icons.content_cut_rounded,
  ToolMode.merge => Icons.merge_rounded,
  ToolMode.compress => Icons.compress_rounded,
  ToolMode.mix => Icons.layers_rounded,
  ToolMode.arrange => Icons.view_timeline_rounded,
  ToolMode.cleanup => Icons.auto_fix_high_rounded,
};

Color _accentFor(ToolMode mode) => switch (mode) {
  ToolMode.videoToAudio || ToolMode.cut => AppColors.accentVideo,
  ToolMode.audioConvert || ToolMode.compress => AppColors.accentAudio,
  ToolMode.merge => AppColors.accentTools,
  ToolMode.mix => const Color(0xFF6F9BFF),
  ToolMode.arrange => AppColors.accentPremium,
  ToolMode.cleanup => AppColors.success,
};

/// Shows that a chosen file is being brought in and checked.
///
/// The picker hands the file over and the app then copies and inspects it,
/// which takes a moment for a long recording. Without a sign of life the
/// disabled buttons look like a frozen screen. Nothing reports how far along
/// the copy is, so the bar is indeterminate rather than a made-up percentage.
class _PickingProgress extends StatelessWidget {
  const _PickingProgress({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!controller.isPicking.value) {
        return const SizedBox.shrink();
      }
      final ThemeData theme = Theme.of(context);

      return Padding(
        padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Uploading file…',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: AppDimens.spaceSm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppDimens.radiusPill),
              child: const LinearProgressIndicator(minHeight: 6),
            ),
          ],
        ),
      );
    });
  }
}

class _SourcePickerActions extends StatelessWidget {
  const _SourcePickerActions({required this.controller, this.compact = false});

  final ConverterController controller;
  final bool compact;

  Future<void> _showLibraryPicker(BuildContext context) async {
    controller.loadLibraryFiles();

    final MediaFile? picked = await showModalBottomSheet<MediaFile>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Obx(() {
            final List<MediaFile> files = controller.libraryFiles;
            final String error = controller.libraryErrorMessage.value;

            return SizedBox(
              height: MediaQuery.of(sheetContext).size.height * 0.7,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimens.pagePadding,
                  0,
                  AppDimens.pagePadding,
                  AppDimens.pagePadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Select from app files',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppDimens.spaceXs),
                    Text(
                      'Previously converted audio saved inside AudioForge.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: AppDimens.spaceLg),
                    if (controller.isLoadingLibrary.value && files.isEmpty)
                      const Expanded(
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error.isNotEmpty && files.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            error,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(sheetContext).colorScheme.error,
                            ),
                          ),
                        ),
                      )
                    else if (files.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'No saved audio found yet. Converted files will appear here.',
                            textAlign: TextAlign.center,
                            style: Theme.of(sheetContext).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.separated(
                          itemCount: files.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AppDimens.spaceSm),
                          itemBuilder: (BuildContext context, int index) {
                            final MediaFile file = files[index];
                            return Card(
                              child: ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.library_music_rounded),
                                ),
                                title: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  <String>[
                                    file.format.toUpperCase(),
                                    Formatters.fileSize(file.sizeInBytes),
                                    if (file.duration != null)
                                      Formatters.duration(file.duration!),
                                  ].join(' • '),
                                ),
                                onTap: () =>
                                    Navigator.of(sheetContext).pop(file),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          }),
        );
      },
    );

    if (picked != null) {
      await controller.pickFromLibrary(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final List<Widget> buttons = <Widget>[
        FilledButton.icon(
          onPressed: controller.isPicking.value ? null : controller.pickSource,
          icon: const Icon(Icons.smartphone_rounded),
          label: Text(
            controller.mode.picksMultiple ? 'Add from phone' : 'Phone files',
          ),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
          onPressed: controller.isPicking.value
              ? null
              : () => _showLibraryPicker(context),
          icon: const Icon(Icons.audio_file_rounded),
          label: Text(
            controller.mode.picksMultiple ? 'Add from app' : 'App files',
          ),
        ),
      ];

      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _PickingProgress(controller: controller),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppDimens.spaceSm,
                runSpacing: AppDimens.spaceSm,
                children: buttons,
              ),
            ),
          ],
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _PickingProgress(controller: controller),
          buttons.first,
          const SizedBox(height: AppDimens.spaceSm),
          Row(
            children: <Widget>[
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimens.spaceMd,
                ),
                child: Text(
                  'OR',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: AppDimens.spaceSm),
          buttons.last,
        ],
      );
    });
  }
}

class _MergeList extends StatelessWidget {
  const _MergeList({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: controller.sources.length,
        onReorderItem: controller.reorderSources,
        itemBuilder: (BuildContext context, int index) {
          final MediaInfo media = controller.sources[index];
          return Padding(
            key: ValueKey<String>('${media.path}#$index'),
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: SourceSummaryCard(
              media: media,
              onRemove: () => controller.removeSourceAt(index),
              leading: ReorderableDragStartListener(
                index: index,
                child: const Padding(
                  padding: EdgeInsets.all(AppDimens.spaceSm),
                  child: Icon(Icons.drag_handle_rounded),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrimSection extends StatelessWidget {
  const _TrimSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final TrimPreviewController preview = Get.find<TrimPreviewController>();
    final TrimWaveformController waveform = Get.find<TrimWaveformController>();

    return Obx(() {
      final Duration total =
          controller.primarySource?.duration ?? Duration.zero;
      if (total == Duration.zero) {
        return const SizedBox.shrink();
      }

      final Duration start = controller.trimStart.value;
      final Duration end = controller.trimEnd.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TrimWaveformFrame(
            child: Obx(() {
              final bool isPlaying = preview.isPlaying.value;

              return TrimWaveform(
                peaks: waveform.peaks.value,
                isLoading: waveform.isLoading.value,
                total: total,
                start: start,
                end: end,
                // The clip is rebased to zero, so the player's position is an
                // offset into the selection rather than into the track.
                playhead: isPlaying ? start + preview.position.value : null,
                isPlaying: isPlaying,
                speed: controller.speed.value.value,
                onChanged: controller.setTrimRange,
              );
            }),
          ),
          _HandleTimes(start: start, end: end, total: total),
          const SizedBox(height: AppDimens.spaceSm),
          // One card, not three. The bounds, the reset and the preview are one
          // job — choosing a section and hearing it — and boxing each of them
          // separately was what made the screen read as clutter.
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimens.spaceLg,
                vertical: AppDimens.spaceMd,
              ),
              child: Column(
                children: <Widget>[
                  _SelectionBounds(controller: controller, total: total),
                  const Divider(height: AppDimens.spaceXl),
                  _PreviewRow(controller: controller, preview: preview),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          OptionChips<ExportSpeed>(
            title: 'Playback speed',
            options: ExportSpeed.values,
            selected: controller.speed.value,
            labelBuilder: (ExportSpeed speed) => speed.label,
            onSelected: controller.setSpeed,
          ),
        ],
      );
    });
  }
}

class _HandleTimes extends StatelessWidget {
  const _HandleTimes({
    required this.start,
    required this.end,
    required this.total,
  });

  final Duration start;
  final Duration end;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final TextStyle? style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    double fractionOf(Duration value) {
      final int totalMs = total.inMilliseconds;
      if (totalMs <= 0) {
        return 0;
      }
      return (value.inMilliseconds / totalMs).clamp(0.0, 1.0);
    }

    return SizedBox(
      height: 20,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double width = constraints.maxWidth;

          // The waveform keeps a margin at each end, so a label placed on the
          // raw fraction would sit beside its handle rather than under it.
          double alignmentFor(Duration value) {
            if (width <= 0) {
              return 0;
            }
            final double track = math.max(
              0,
              width - TrimWaveform.edgeInset * 2,
            );
            final double centre =
                TrimWaveform.edgeInset + fractionOf(value) * track;
            // Alignment.x runs -1..1, pulled in from the edges so a label at
            // either end is not clipped.
            return (centre / width * 2 - 1).clamp(-0.94, 0.94);
          }

          return Stack(
            children: <Widget>[
              Align(
                alignment: Alignment(alignmentFor(start), 0),
                child: Text(Formatters.duration(start), style: style),
              ),
              Align(
                alignment: Alignment(alignmentFor(end), 0),
                child: Text(Formatters.duration(end), style: style),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Start and end as read-outs, with the reset between them.
class _SelectionBounds extends StatelessWidget {
  const _SelectionBounds({required this.controller, required this.total});

  final ConverterController controller;
  final Duration total;

  @override
  Widget build(BuildContext context) {
    final Duration start = controller.trimStart.value;
    final Duration end = controller.trimEnd.value;
    final bool isWholeTrack = start == Duration.zero && end == total;

    return Row(
      children: <Widget>[
        _BoundReadout(label: 'Start', value: start),
        Expanded(
          child: Center(
            child: TextButton(
              // Nothing to undo on an untouched track, and an enabled reset
              // there invites a tap that does nothing.
              onPressed: isWholeTrack
                  ? null
                  : () => controller.setTrimRange(Duration.zero, total),
              child: const Text('Reset'),
            ),
          ),
        ),
        _BoundReadout(
          label: 'End',
          value: end,
          alignment: CrossAxisAlignment.end,
        ),
      ],
    );
  }
}

class _BoundReadout extends StatelessWidget {
  const _BoundReadout({
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final Duration value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignment,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          Formatters.duration(value),
          style: theme.textTheme.titleMedium?.copyWith(
            // Tabular figures so the numbers do not jitter sideways while a
            // handle is being dragged.
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// Play control, elapsed time and progress, on one line.
class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.controller, required this.preview});

  final ConverterController controller;
  final TrimPreviewController preview;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ThemeData theme = Theme.of(context);
      final Duration start = controller.trimStart.value;
      final Duration end = controller.trimEnd.value;
      final Duration selected = end > start ? end - start : Duration.zero;
      final MediaInfo? source = controller.primarySource;
      final bool isPlaying = preview.isPlaying.value;
      final bool isPreparing = preview.isPreparing.value;

      final Duration heard = isPlaying ? preview.position.value : Duration.zero;
      final double played = selected.inMilliseconds <= 0
          ? 0
          : (heard.inMilliseconds / selected.inMilliseconds).clamp(0.0, 1.0);

      return Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _PlayButton(
                isPlaying: isPlaying,
                isPreparing: isPreparing,
                // Stop is its own call rather than a second toggle: toggling
                // asked the controller to match the tag it had stored, so
                // anything that left that bookkeeping stale turned the stop
                // into a no-op and the preview could not be switched off.
                onPressed: source == null
                    ? null
                    : () => isPlaying
                          ? preview.stop()
                          : preview.toggle(
                              source: source.playableSource,
                              start: start,
                              end: end,
                              speed: controller.speed.value.value,
                            ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                  child: LinearProgressIndicator(value: played, minHeight: 6),
                ),
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Text(
                '${Formatters.duration(heard)} / '
                '${Formatters.duration(selected)}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFeatures: const <FontFeature>[
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ],
          ),
          if (preview.errorMessage.value.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppDimens.spaceSm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                preview.errorMessage.value,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.isPlaying,
    required this.isPreparing,
    required this.onPressed,
  });

  final bool isPlaying;
  final bool isPreparing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    final Color backgroundColor = onPressed == null
        ? colors.onSurfaceVariant
        : colors.primary;

    return SizedBox(
      width: 48,
      height: 48,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: isPreparing
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
          ),
        ),
      ),
    );
  }
}

/// How the layered tracks are lined up against each other.
class _MixSection extends StatelessWidget {
  const _MixSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final bool isLooping = controller.loopShorterTracks.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Mixing', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppDimens.spaceSm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isLooping,
            onChanged: controller.setLoopShorterTracks,
            title: const Text('Repeat layers to fill the main track'),
            subtitle: const Text(
              'A short background sound plays over and over instead of '
              'stopping partway through.',
            ),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // Repeating makes a layer endless, so the main track is the only
          // thing left that can end the mix; the choice is shown as settled
          // rather than offered and silently overridden.
          if (isLooping)
            Text(
              'Length follows the main track while layers repeat.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            OptionChips<MixLengthMode>(
              title: 'Stop after',
              options: MixLengthMode.values,
              selected: controller.mixLength.value,
              labelBuilder: (MixLengthMode mode) => mode.label,
              onSelected: controller.setMixLength,
            ),
          const SizedBox(height: AppDimens.spaceXl),
          _MixPreviewCard(controller: controller),
        ],
      );
    });
  }
}

/// Plays every track together so the balance can be set by ear.
class _MixPreviewCard extends StatelessWidget {
  const _MixPreviewCard({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final MixPreviewController preview = Get.find<MixPreviewController>();

    return Obx(() {
      final ThemeData theme = Theme.of(context);
      final ColorScheme colors = theme.colorScheme;
      final bool hasEnoughTracks = controller.sources.isNotEmpty;
      final bool isPlaying = preview.isPlaying.value;
      final bool isPreparing = preview.isPreparing.value;
      final Duration? total = controller.longestClipLength;
      final Duration position = preview.position.value;
      final double fraction = total == null || total <= Duration.zero
          ? 0
          : (position.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'Preview all',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasEnoughTracks
                              ? 'All tracks play together, following the '
                                    'volume shaping you set.'
                              : 'Add a track to hear it.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.spaceSm),
                  FilledButton.icon(
                    // The theme makes filled buttons full width, which a
                    // button sharing a row with a title cannot be.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceMd,
                      ),
                    ),
                    onPressed: !hasEnoughTracks || isPreparing
                        ? null
                        : controller.toggleMixPreview,
                    icon: isPreparing
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isPlaying
                                ? Icons.stop_rounded
                                : Icons.play_arrow_rounded,
                          ),
                    label: Text(isPlaying ? 'Stop' : 'Preview'),
                  ),
                ],
              ),
              if (total != null) ...<Widget>[
                const SizedBox(height: AppDimens.spaceMd),
                Row(
                  children: <Widget>[
                    Text(
                      Formatters.duration(position),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimens.spaceSm,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            AppDimens.radiusPill,
                          ),
                          child: LinearProgressIndicator(
                            value: fraction,
                            minHeight: 6,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      Formatters.duration(total),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontFeatures: const <FontFeature>[
                          FontFeature.tabularFigures(),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (preview.errorMessage.value.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  preview.errorMessage.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.error,
                  ),
                ),
              ],
              const SizedBox(height: AppDimens.spaceSm),
              // The preview starts the tracks together but does not lock them
              // to each other, so this is worth saying rather than letting a
              // small drift read as a bug in the export.
              Text(
                'A preview for balance. The export renders the finished mix.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

/// How the clips are laid out, and how long that makes the finished track.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ThemeData theme = Theme.of(context);
      final Duration? total = controller.sourceDuration;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('Timeline', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppDimens.spaceMd),
          _TimelineStrip(controller: controller),
          const SizedBox(height: AppDimens.spaceLg),
          Text(
            total == null
                ? 'Total length will be known once every clip is read.'
                : 'Total length ${Formatters.duration(total)}',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppDimens.spaceXs),
          Text(
            'Clips play straight through in this order, with no gap between '
            'them. Drag a clip to change where it comes.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          _TimelinePreviewCard(controller: controller),
        ],
      );
    });
  }
}

/// Plays the clips straight through so the finished track can be heard.
class _TimelinePreviewCard extends StatelessWidget {
  const _TimelinePreviewCard({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final TimelinePreviewController preview =
        Get.find<TimelinePreviewController>();

    return Obx(() {
      final ThemeData theme = Theme.of(context);
      final bool isPlaying = preview.isPlaying.value;
      final bool hasClips = controller.sources.isNotEmpty;

      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppDimens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Preview the track', style: theme.textTheme.titleSmall),
              const SizedBox(height: AppDimens.spaceXs),
              Text(
                'Plays every clip in order, one running straight into the '
                'next.',
                style: theme.textTheme.bodyMedium,
              ),
              if (isPlaying) ...<Widget>[
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  '${Formatters.duration(preview.position.value)}'
                  '  ·  Clip ${preview.currentClip.value + 1}',
                  style: theme.textTheme.titleMedium,
                ),
              ],
              const SizedBox(height: AppDimens.spaceMd),
              FilledButton.icon(
                onPressed: !hasClips || preview.isPreparing.value
                    ? null
                    : () => preview.toggle(
                        clips: controller.sources.toList(),
                        tracks: List<MixTrack>.of(controller.clips),
                      ),
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isPlaying ? 'Stop preview' : 'Play the track'),
              ),
              if (preview.isPreparing.value) ...<Widget>[
                const SizedBox(height: AppDimens.spaceMd),
                const LinearProgressIndicator(),
              ],
              if (preview.errorMessage.value.isNotEmpty) ...<Widget>[
                const SizedBox(height: AppDimens.spaceMd),
                Text(
                  preview.errorMessage.value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}

/// The whole track at a glance: every clip in place, end to end.
class _TimelineStrip extends StatelessWidget {
  const _TimelineStrip({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final TimelinePreviewController preview =
        Get.find<TimelinePreviewController>();

    return Obx(() {
      final Duration? total = controller.sourceDuration;
      if (total == null || total == Duration.zero) {
        return const SizedBox.shrink();
      }

      // Numbered by where a clip actually lands in the picture, not by its
      // place among the sources: a clip whose length could not be read
      // contributes nothing and is left out here too, and the clips after it
      // must not jump a number over the gap it leaves.
      final List<TimelineClip> clips = <TimelineClip>[];
      for (int index = 0; index < controller.sources.length; index++) {
        // The selected part is what plays, so it is what the block shows.
        if (controller.usedLengthOf(index) case final Duration length) {
          clips.add(
            TimelineClip(
              label: '${clips.length + 1}',
              start: controller.startOfTrack(index),
              length: length,
            ),
          );
        }
      }

      return ClipTimelineStrip(
        clips: clips,
        total: total,
        // The marker only means something while something is playing.
        playhead: preview.isPlaying.value ? preview.position.value : null,
      );
    });
  }
}

/// What the noise remover strips out, and how hard it works at it.
class _CleanupSection extends StatelessWidget {
  const _CleanupSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ThemeData theme = Theme.of(context);
      final CleanupMode mode = controller.cleanupMode.value;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OptionChips<CleanupMode>(
            title: 'Remove',
            options: CleanupMode.values,
            selected: mode,
            labelBuilder: (CleanupMode value) => value.label,
            onSelected: controller.setCleanupMode,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            mode.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (controller.isCleanupUnsupported) ...<Widget>[
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'This track is mono, so it has no separate centre channel to '
              'remove. Pick another option.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ],
          if (mode.usesStrength) ...<Widget>[
            const SizedBox(height: AppDimens.spaceXl),
            OptionChips<NoiseStrength>(
              title: 'Strength',
              options: NoiseStrength.values,
              selected: controller.noiseStrength.value,
              labelBuilder: (NoiseStrength value) => value.label,
              onSelected: controller.setNoiseStrength,
            ),
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Stronger settings remove more noise and take more of the '
              'audio with it. Start light if the result sounds hollow.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _FormatSection extends StatelessWidget {
  const _FormatSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          OptionChips<AudioFormat>(
            title: 'Output format',
            options: controller.mode.availableFormats,
            selected: controller.format.value,
            labelBuilder: (AudioFormat format) => format.label,
            onSelected: controller.setFormat,
          ),
          // Bitrate is meaningless for uncompressed output, so it is hidden
          // rather than shown disabled.
          if (controller.format.value.supportsBitrate) ...<Widget>[
            const SizedBox(height: AppDimens.spaceXl),
            OptionChips<AudioQuality>(
              title: 'Quality',
              options: AudioQuality.values,
              selected: controller.quality.value,
              labelBuilder: (AudioQuality quality) => quality.label,
              onSelected: controller.setQuality,
            ),
          ],
        ],
      ),
    );
  }
}

class _CompressionSection extends StatelessWidget {
  const _CompressionSection({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final Duration? duration = controller.sourceDuration;
      final CompressionLevel level = controller.compressionLevel.value;
      final int? original = controller.primarySource?.sizeInBytes;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (original != null)
            Text(
              'Original size: ${Formatters.fileSize(original)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          const SizedBox(height: AppDimens.spaceLg),
          OptionChips<CompressionLevel>(
            title: 'Target quality',
            options: CompressionLevel.values,
            selected: level,
            labelBuilder: (CompressionLevel value) => value.label,
            onSelected: controller.setCompressionLevel,
          ),
          if (duration != null) ...<Widget>[
            const SizedBox(height: AppDimens.spaceMd),
            Text(
              'Estimated output: about '
              '${Formatters.fileSize(level.estimatedSizeInBytes(duration))}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    });
  }
}

class _FileNameField extends StatefulWidget {
  const _FileNameField({required this.controller});

  final ConverterController controller;

  @override
  State<_FileNameField> createState() => _FileNameFieldState();
}

class _FileNameFieldState extends State<_FileNameField> {
  late final TextEditingController _textController = TextEditingController(
    text: widget.controller.fileName.value,
  );

  late final Worker _worker = ever<String>(widget.controller.fileName, (
    String value,
  ) {
    // Keeps the field in sync when a new selection regenerates the name,
    // without fighting the user while they are typing.
    if (_textController.text != value) {
      _textController.text = value;
    }
  });

  @override
  void initState() {
    super.initState();
    _worker;
  }

  @override
  void dispose() {
    _worker.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('File name', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _textController,
          onChanged: widget.controller.setFileName,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: 'Output file name',
            suffixText: '.${widget.controller.format.value.extension}',
          ),
        ),
      ],
    );
  }
}
