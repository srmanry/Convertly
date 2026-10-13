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
import '../controllers/cleanup_preview_controller.dart';
import '../controllers/converter_controller.dart';
import '../controllers/mix_preview_controller.dart';
import '../controllers/timeline_preview_controller.dart';
import '../controllers/trim_preview_controller.dart';
import '../controllers/trim_waveform_controller.dart';
import '../widgets/clip_timeline_strip.dart';
import '../widgets/timeline_preview_panel.dart';
import '../widgets/timeline_export_options.dart';
import '../widgets/mix_track_list.dart';
import '../widgets/option_chips.dart';
import '../widgets/source_summary_card.dart';
import '../widgets/trim_waveform.dart';
import 'conversion_progress_view.dart';
import '../../../../core/i18n/translation_keys.dart';

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
        title: K.conversionFailed.tr,
        message: controller.errorMessage.value.isNotEmpty
            ? controller.errorMessage.value
            : K.errorConversion.tr,
        action: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FilledButton.icon(
              onPressed: controller.retry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(K.tryAgain.tr),
            ),
            const SizedBox(height: AppDimens.spaceMd),
            TextButton(
              onPressed: () =>
                  Get.until((Route<dynamic> route) => route.isFirst),
              child: Text(K.backToHome.tr),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigurationView extends StatefulWidget {
  const _ConfigurationView({required this.controller});

  final ConverterController controller;

  @override
  State<_ConfigurationView> createState() => _ConfigurationViewState();
}

class _ConfigurationViewState extends State<_ConfigurationView> {
  bool _clipsExpanded = true;
  ConverterController get controller => widget.controller;

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
          if (controller.mode.isTimeline)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                AppDimens.pagePadding,
                AppDimens.pagePadding,
                AppDimens.spaceLg,
              ),
              child: InkWell(
                key: const ValueKey<String>('timeline-clips-toggle'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() => _clipsExpanded = !_clipsExpanded),
                child: Row(
                  children: <Widget>[
                    Expanded(child: _TimelineHeading(controller: controller)),
                    Icon(
                      _clipsExpanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                AppDimens.pagePadding,
                controller.mode.isTimeline ? 0 : AppDimens.pagePadding,
                AppDimens.pagePadding,
                AppDimens.pagePadding,
              ),
              children: <Widget>[
                if (controller.mode.isMix) ...<Widget>[
                  Text(
                    K.adjustVolumeOverTime.tr,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceXs),
                  Text(
                    controller.envelopeOf(0).points.length <= 2
                        ? K.volumeLaneHint.tr
                        : K.volumeLaneAdjust.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppDimens.spaceLg),
                ],
                if (controller.mode.combinesTracks)
                  Visibility(
                    visible: !controller.mode.isTimeline || _clipsExpanded,
                    maintainState: true,
                    child: MixTrackList(
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
                              for (
                                int i = 0;
                                i < controller.sources.length;
                                i++
                              )
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
                      onTrackPreview: controller.mode.isMix
                          ? controller.toggleTrackPreview
                          : null,
                      // Read inside the Obx so a track starting or stopping
                      // moves only its own button.
                      previewingTrack: controller.mode.isMix
                          ? Get.find<MixPreviewController>().soloTrack.value
                          : null,
                      isPreviewPreparing:
                          controller.mode.isMix &&
                          Get.find<MixPreviewController>().isPreparing.value,
                      showsPositions: controller.mode.isTimeline,
                      onRemove: controller.removeSourceAt,
                      onReorder: controller.reorderSources,
                    ),
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
                  _SourcePickerActions(controller: controller),
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
                    label: Text(K.addMoreFiles.tr),
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
                if (controller.mode.isTimeline)
                  _TimelineExportSettings(controller: controller)
                else ...<Widget>[
                  if (controller.mode.isCompression)
                    _CompressionSection(controller: controller)
                  else
                    _FormatSection(controller: controller),
                  const SizedBox(height: AppDimens.spaceXl),
                  _FileNameField(controller: controller),
                ],
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
          if (controller.mode.isTimeline)
            _TimelineExportBar(controller: controller)
          else
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
      ToolMode.videoToAudio => K.actionExtractAudio.tr,
      ToolMode.audioConvert => K.actionConvert.tr,
      ToolMode.cut => K.actionCutAudio.tr,
      ToolMode.merge => K.actionMergeFiles.tr,
      ToolMode.compress => K.actionCompress.tr,
      ToolMode.mix => K.actionMixTracks.tr,
      ToolMode.arrange => K.actionBuildTrack.tr,
      ToolMode.cleanup => K.actionRemoveNoise.tr,
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
                                K.chooseASource.tr,
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
              K.uploadingFile.tr,
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
  const _SourcePickerActions({required this.controller});

  final ConverterController controller;

  Future<void> _showLibraryPicker(BuildContext context) async {
    controller.loadLibraryFiles();

    final List<MediaFile>? picked = await showModalBottomSheet<List<MediaFile>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _LibraryPickerSheet(
          controller: controller,
          allowsMultiple: controller.mode.picksMultiple,
        );
      },
    );

    if (picked != null && picked.isNotEmpty) {
      await controller.pickFromLibraryFiles(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ColorScheme colors = Theme.of(context).colorScheme;
      final ButtonStyle style = OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        backgroundColor: colors.primary.withValues(alpha: 0.10),
        foregroundColor: colors.onSurface,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.30)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        textStyle: Theme.of(context).textTheme.labelMedium,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _PickingProgress(controller: controller),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  style: style,
                  onPressed: controller.isPicking.value
                      ? null
                      : controller.pickSource,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(K.addFromPhone.tr, textAlign: TextAlign.center),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  style: style,
                  onPressed: controller.isPicking.value
                      ? null
                      : () => _showLibraryPicker(context),
                  icon: const Icon(Icons.audio_file_outlined, size: 18),
                  label: Text(K.addFromApp.tr, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _LibraryPickerSheet extends StatefulWidget {
  const _LibraryPickerSheet({
    required this.controller,
    required this.allowsMultiple,
  });

  final ConverterController controller;
  final bool allowsMultiple;

  @override
  State<_LibraryPickerSheet> createState() => _LibraryPickerSheetState();
}

class _LibraryPickerSheetState extends State<_LibraryPickerSheet> {
  /// Side margin for everything under the header, which keeps the full width.
  static const EdgeInsets _gutter = EdgeInsets.symmetric(
    horizontal: AppDimens.pagePadding,
  );

  final Set<MediaFile> _selected = <MediaFile>{};
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(MediaFile file) {
    setState(() {
      if (widget.allowsMultiple) {
        _selected.contains(file) ? _selected.remove(file) : _selected.add(file);
      } else {
        _selected
          ..clear()
          ..add(file);
      }
    });
  }

  /// Ticks every file the search currently shows, or unticks them when they
  /// are all ticked already. A filtered-out file keeps whatever it was, so a
  /// search never silently drops a pick made before it.
  void _toggleAll(List<MediaFile> files) {
    setState(() {
      if (files.every(_selected.contains)) {
        _selected.removeAll(files);
      } else {
        _selected.addAll(files);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.9,
        // No side padding on the sheet itself: the header sits against the
        // edge like an app bar, and everything below adds its own gutter.
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppDimens.pagePadding),
          child: Obx(() {
            final List<MediaFile> files = widget.controller.libraryFiles;
            final String error = widget.controller.libraryErrorMessage.value;
            final String query = _query.trim().toLowerCase();
            final List<MediaFile> visibleFiles = query.isEmpty
                ? files
                : files
                      .where(
                        (MediaFile file) =>
                            file.name.toLowerCase().contains(query) ||
                            file.format.toLowerCase().contains(query),
                      )
                      .toList();

            // Every file on screen already ticked: the same control then
            // clears them, so one button covers both directions.
            final bool allVisibleSelected =
                visibleFiles.isNotEmpty &&
                visibleFiles.every(_selected.contains);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.only(right: AppDimens.spaceSm),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: K.back.tr,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      Expanded(
                        child: Text(
                          K.selectFromAppFiles.tr,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (widget.allowsMultiple && visibleFiles.isNotEmpty)
                        TextButton(
                          onPressed: () => _toggleAll(visibleFiles),
                          child: Text(
                            allVisibleSelected ? K.clearAll.tr : K.selectAll.tr,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Padding(
                  padding: _gutter,
                  child: Text(
                    widget.allowsMultiple
                        ? K.pickTapOrSelectAll.tr
                        : K.pickOneFile.tr,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceLg),
                Padding(
                  padding: _gutter,
                  child: TextField(
                    key: const ValueKey<String>('library-search-field'),
                    controller: _searchController,
                    onChanged: (String value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: K.searchAppFiles.tr,
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: K.clearSearch.tr,
                              onPressed: () {
                                FocusScope.of(context).unfocus();
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                if (widget.controller.isLoadingLibrary.value && files.isEmpty)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (error.isNotEmpty && files.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: _gutter,
                        child: Text(
                          error,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  )
                else if (files.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: _gutter,
                        child: Text(
                          K.noSavedAudio.tr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else if (visibleFiles.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: _gutter,
                        child: Text(
                          K.noAudioMatchesSearch.tr,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.separated(
                      padding: _gutter,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: visibleFiles.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppDimens.spaceSm),
                      itemBuilder: (BuildContext context, int index) {
                        final MediaFile file = visibleFiles[index];
                        final bool selected = _selected.contains(file);
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: ListTile(
                            selected: selected,
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
                            trailing: widget.allowsMultiple
                                ? Checkbox(
                                    value: selected,
                                    onChanged: (_) => _toggle(file),
                                  )
                                : Icon(
                                    selected
                                        ? Icons.radio_button_checked_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                            onTap: () => _toggle(file),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppDimens.spaceMd),
                Padding(
                  padding: _gutter,
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _selected.isEmpty
                          ? null
                          : () => Navigator.of(context).pop(
                              files
                                  .where(_selected.contains)
                                  .toList(growable: false),
                            ),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(
                        _selected.isEmpty
                            ? widget.allowsMultiple
                                  ? K.selectFiles.tr
                                  : K.selectAFile.tr
                            : widget.allowsMultiple
                            ? K.addNFiles.trParams(<String, String>{
                                'count': '${_selected.length}',
                              })
                            : K.addSelectedFile.tr,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
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
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          K.trimSelection.tr,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: start == Duration.zero && end == total
                            ? null
                            : () =>
                                  controller.setTrimRange(Duration.zero, total),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(K.reset.tr),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
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
                        playhead: isPlaying
                            ? start + preview.position.value
                            : null,
                        isPlaying: isPlaying,
                        speed: controller.speed.value.value,
                        onChanged: controller.setTrimRange,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  _SelectionBounds(controller: controller),
                  const Divider(height: 24),
                  _PreviewRow(controller: controller, preview: preview),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimens.spaceXl),
          OptionChips<ExportSpeed>(
            title: K.playbackSpeed.tr,
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

/// The selected bounds, shown once beneath the waveform.
class _SelectionBounds extends StatelessWidget {
  const _SelectionBounds({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final Duration start = controller.trimStart.value;
    final Duration end = controller.trimEnd.value;

    return Row(
      children: <Widget>[
        _BoundReadout(label: K.startLabel.tr, value: start),
        const Spacer(),
        _BoundReadout(
          label: K.endLabel.tr,
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
          style: theme.textTheme.labelLarge?.copyWith(
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
      width: 36,
      height: 36,
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Center(
            child: isPreparing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 24,
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
          Text(
            K.mixingSection.tr,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppDimens.spaceSm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: isLooping,
            onChanged: controller.setLoopShorterTracks,
            title: Text(K.repeatLayers.tr),
            subtitle: Text(K.repeatLayersDesc.tr),
          ),
          const SizedBox(height: AppDimens.spaceMd),
          // Repeating makes a layer endless, so the main track is the only
          // thing left that can end the mix; the choice is shown as settled
          // rather than offered and silently overridden.
          if (isLooping)
            Text(
              K.lengthFollowsMain.tr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            OptionChips<MixLengthMode>(
              title: K.stopAfter.tr,
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
      // Only when the whole mix is running. A single track being auditioned
      // from its own card must not turn this button into Stop, or the two
      // controls would look like one.
      final bool isPlaying =
          preview.isPlaying.value && preview.soloTrack.value == null;
      final bool isPreparing =
          preview.isPreparing.value && preview.soloTrack.value == null;
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
                          K.previewAll.tr,
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
                        : () => controller.toggleMixPreview(),
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
                    label: Text(isPlaying ? K.stop.tr : K.preview.tr),
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
                K.previewBalanceNote.tr,
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

/// A quick orientation before the editable clips.
class _TimelineHeading extends StatelessWidget {
  const _TimelineHeading({required this.controller});
  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          K.timelineClips.trParams(<String, String>{
            'count': '${controller.sources.length}',
          }),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          K.timelineEditHint.tr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _TimelineExportSettings extends StatelessWidget {
  const _TimelineExportSettings({required this.controller});
  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('timeline-export-settings'),
        shape: const Border(),
        collapsedShape: const Border(),
        leading: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
        title: Text(K.exportSettings.tr, style: theme.textTheme.titleSmall),
        subtitle: Text(
          '${controller.format.value.label}${controller.format.value.supportsBitrate ? ' · ${controller.quality.value.label}' : ''}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: <Widget>[
          Obx(
            () => TimelineExportOptions(
              formats: controller.mode.availableFormats,
              format: controller.format.value,
              quality: controller.quality.value,
              onFormatChanged: controller.setFormat,
              onQualityChanged: controller.setQuality,
            ),
          ),
          const SizedBox(height: 20),
          // The text field's horizontal scroll offset needs its own storage
          // identity, separate from ExpansionTile's stored expansion bool.
          KeyedSubtree(
            key: const PageStorageKey<String>('timeline-output-name'),
            child: _FileNameField(controller: controller),
          ),
        ],
      ),
    );
  }
}

/// Keeps the track length and final action visible while editing.
class _TimelineExportBar extends StatelessWidget {
  const _TimelineExportBar({required this.controller});
  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              controller.sourceDuration == null
                  ? K.timelineTotalUnknown.tr
                  : K.timelineTotal.trParams(<String, String>{
                      'duration': Formatters.duration(
                        controller.sourceDuration!,
                      ),
                    }),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              onPressed: controller.canConvert ? controller.convert : null,
              icon: const Icon(Icons.check_rounded),
              label: Text(
                K.actionBuildTrack.tr,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overview and playback share a single timeline surface.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.controller});
  final ConverterController controller;

  @override
  Widget build(BuildContext context) =>
      _TimelinePreviewCard(controller: controller);
}

/// Connects the sequence overview to the existing preview player.
class _TimelinePreviewCard extends StatelessWidget {
  const _TimelinePreviewCard({required this.controller});
  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final TimelinePreviewController preview =
        Get.find<TimelinePreviewController>();
    return Obx(() {
      final List<TimelineClip> clips = <TimelineClip>[];
      final List<int> sourceOf = <int>[];
      for (int index = 0; index < controller.sources.length; index++) {
        if (controller.usedLengthOf(index) case final Duration length) {
          clips.add(
            TimelineClip(
              label: '${index + 1}',
              name: controller.sources[index].name,
              start: controller.startOfTrack(index),
              length: length,
            ),
          );
          sourceOf.add(index);
        }
      }
      return TimelinePreviewPanel(
        clips: clips,
        total: controller.sourceDuration,
        position: preview.position.value,
        isPlaying: preview.isPlaying.value,
        isPreparing: preview.isPreparing.value,
        errorMessage: preview.errorMessage.value,
        onPreview: controller.sources.isEmpty
            ? null
            : () => preview.toggle(
                clips: controller.sources.toList(),
                tracks: List<MixTrack>.of(controller.clips),
              ),
        onReorder: sourceOf.length < 2
            ? null
            : (int from, int to) => controller.reorderSources(
                sourceOf[from],
                sourceOf[to.clamp(0, sourceOf.length - 1)],
              ),
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
          _CleanupGroup(
            title: K.removeSection.tr,
            child: Column(
              children: <Widget>[
                for (final CleanupMode option
                    in CleanupMode.values) ...<Widget>[
                  _CleanupModeTile(
                    mode: option,
                    selected: option == mode,
                    onTap: () => controller.setCleanupMode(option),
                  ),
                  if (option != CleanupMode.values.last)
                    const SizedBox(height: AppDimens.spaceSm),
                ],
              ],
            ),
          ),
          if (controller.isCleanupUnsupported) ...<Widget>[
            const SizedBox(height: AppDimens.spaceMd),
            _CleanupNotice(message: K.cleanupMonoWarning.tr),
          ],
          const SizedBox(height: AppDimens.spaceXl),
          _CleanupPreviewCard(controller: controller),
          if (mode.usesStrength) ...<Widget>[
            const SizedBox(height: AppDimens.spaceXl),
            _CleanupGroup(
              title: K.strengthSection.tr,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _StrengthSegments(
                    selected: controller.noiseStrength.value,
                    onSelected: controller.setNoiseStrength,
                  ),
                  const SizedBox(height: AppDimens.spaceMd),
                  Text(
                    K.strengthHint.tr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      );
    });
  }
}

/// A plain labelled group of cleanup choices.
///
/// No border of its own: the tiles inside already carry one, and wrapping
/// them in a second box was what made the screen look boxed-in. A bare label
/// also matches the sections below it, which have always been plain text.
class _CleanupGroup extends StatelessWidget {
  const _CleanupGroup({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppDimens.spaceMd),
        child,
      ],
    );
  }
}

/// One cleanup mode, with the line explaining it kept beside its own name.
///
/// The three descriptions used to share a single line under the chips, which
/// left the reader matching text to a selection they had already made.
class _CleanupModeTile extends StatelessWidget {
  const _CleanupModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final CleanupMode mode;
  final bool selected;
  final VoidCallback onTap;

  /// Picture for each mode, so the list can be scanned without reading.
  IconData get _icon => switch (mode) {
    CleanupMode.backgroundNoise => Icons.waves_rounded,
    CleanupMode.voiceFocus => Icons.record_voice_over_rounded,
    CleanupMode.removeVocals => Icons.music_off_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(AppDimens.spaceMd),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.success.withValues(alpha: 0.12)
                : theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: selected
                  ? AppColors.success.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Icon(
                _icon,
                size: 20,
                color: selected
                    ? AppColors.success
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mode.label,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.success : null,
                      ),
                    ),
                    // Only the chosen mode explains itself. Three paragraphs
                    // at once filled the screen, and two of them described
                    // something that was not going to happen.
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topLeft,
                      child: selected
                          ? Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                mode.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey<String>('on'),
                        size: 20,
                        color: AppColors.success,
                      )
                    : Icon(
                        Icons.circle_outlined,
                        key: const ValueKey<String>('off'),
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three strengths as one track rather than three loose chips.
///
/// Light to strong is a scale, and separate chips gave no sign of that.
class _StrengthSegments extends StatelessWidget {
  const _StrengthSegments({required this.selected, required this.onSelected});

  final NoiseStrength selected;
  final ValueChanged<NoiseStrength> onSelected;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      ),
      child: Row(
        children: <Widget>[
          for (final NoiseStrength option in NoiseStrength.values)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(option),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimens.spaceMd,
                    ),
                    decoration: BoxDecoration(
                      color: option == selected
                          ? AppColors.success.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      border: Border.all(
                        color: option == selected
                            ? AppColors.success.withValues(alpha: 0.55)
                            : Colors.transparent,
                      ),
                    ),
                    child: Text(
                      option.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: option == selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: option == selected
                            ? AppColors.success
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Why the export is blocked, said where the choice that blocked it was made.
class _CleanupNotice extends StatelessWidget {
  const _CleanupNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimens.spaceMd),
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lets the clean-up be heard before the whole file is committed to it.
///
/// Two sides rather than one button: a denoised sample on its own tells you
/// little, because what matters is what it took out of the original.
class _CleanupPreviewCard extends StatelessWidget {
  const _CleanupPreviewCard({required this.controller});

  final ConverterController controller;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final CleanupPreviewController preview =
        Get.find<CleanupPreviewController>();

    return Obx(() {
      final MediaInfo? source = controller.primarySource;
      if (source == null) {
        return const SizedBox.shrink();
      }

      final String playing = preview.playingTag.value;
      final bool rendering = preview.isRendering.value;
      final String error = preview.errorMessage.value;

      return _CleanupGroup(
        title: K.previewSection.tr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _PreviewButton(
                    label: K.previewOriginal.tr,
                    playing:
                        playing == CleanupPreviewTag.original &&
                        preview.isPlaying.value,
                    busy: false,
                    accent: theme.colorScheme.onSurfaceVariant,
                    onTap: rendering ? null : controller.togglePreviewOriginal,
                  ),
                ),
                const SizedBox(width: AppDimens.spaceSm),
                Expanded(
                  child: _PreviewButton(
                    label: K.previewCleaned.tr,
                    playing:
                        playing == CleanupPreviewTag.cleaned &&
                        preview.isPlaying.value,
                    busy: rendering,
                    accent: AppColors.success,
                    onTap: rendering ? null : controller.togglePreviewCleaned,
                  ),
                ),
              ],
            ),
            // Nothing is said here unless something went wrong: the two
            // buttons explain themselves.
            if (error.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppDimens.spaceMd),
              Text(
                error,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

/// One side of the preview, which doubles as its own pause button.
class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.label,
    required this.playing,
    required this.busy,
    required this.accent,
    required this.onTap,
  });

  final String label;

  /// True only while sound is coming out, so a paused side offers to resume
  /// rather than claiming to be playing.
  final bool playing;
  final bool busy;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool lit = playing || busy;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(
            vertical: AppDimens.spaceMd,
            horizontal: AppDimens.spaceSm,
          ),
          decoration: BoxDecoration(
            color: lit
                ? accent.withValues(alpha: 0.16)
                : theme.colorScheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            border: Border.all(
              color: lit
                  ? accent.withValues(alpha: 0.6)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: lit ? 1.4 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              SizedBox(
                width: 20,
                height: 20,
                child: busy
                    ? CircularProgressIndicator(strokeWidth: 2, color: accent)
                    : Icon(
                        playing
                            ? Icons.pause_circle_rounded
                            : Icons.play_circle_outline_rounded,
                        size: 20,
                        color: lit
                            ? accent
                            : theme.colorScheme.onSurfaceVariant,
                      ),
              ),
              const SizedBox(width: AppDimens.spaceSm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: lit ? accent : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
            title: K.outputFormatSection.tr,
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
              title: K.qualitySection.tr,
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
            title: K.targetQualitySection.tr,
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
        Text(
          K.fileNameSection.tr,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppDimens.spaceMd),
        TextField(
          controller: _textController,
          onChanged: widget.controller.setFileName,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            hintText: K.outputFileNameHint.tr,
            suffixText: '.${widget.controller.format.value.extension}',
          ),
        ),
      ],
    );
  }
}
