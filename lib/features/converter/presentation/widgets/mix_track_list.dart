import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/entities/volume_envelope.dart';
import 'mixer_track_card.dart';
import 'source_summary_card.dart';
import 'timeline_clip_card.dart';
import '../../../../core/i18n/translation_keys.dart';

/// The mixer's track list: every clip with its own start point and volume.
///
/// Order is what makes a track the main one, so the list is reorderable for
/// the same reason the merge list is — dragging a track to the top is how the
/// user says which one everything else sits behind.
class MixTrackList extends StatelessWidget {
  const MixTrackList({
    required this.sources,
    required this.volumes,
    required this.starts,
    required this.onVolumeChanged,
    required this.onRemove,
    required this.onReorder,
    super.key,
    this.showsPositions = false,
    this.trimRanges,
    this.onTrimChanged,
    this.onPreviewClip,
    this.previewingClip,
    this.previewingTrack,
    this.previewError,
    this.previewErrorClip,
    this.envelopes,
    this.onEnvelopeChanged,
    this.onEnvelopeCleared,
    this.playheadOf,
    this.isPreviewPreparing = false,
    this.onTrackPreview,
  });

  /// Loudest a layer can be pushed. Above this the limiter is doing more work
  /// than the volume is, so the slider stops here.
  static const double maxVolume = 2;

  final List<MediaInfo> sources;
  final List<double> volumes;
  final List<Duration> starts;

  /// Null on the timeline, where clips play in turn and nothing has to be
  /// balanced against anything else.
  final void Function(int index, double volume)? onVolumeChanged;

  /// Numbers each row and shows when it plays.
  ///
  /// Positions are derived from the order, so they are reported rather than
  /// offered for editing: there is no way to leave a clip stranded after a
  /// stretch of silence.
  final bool showsPositions;

  /// The part of each clip currently selected, when clips can be cut.
  final List<(Duration start, Duration end)>? trimRanges;

  final void Function(int index, Duration start, Duration end)? onTrimChanged;

  /// Plays just the selection on one clip, so it can be checked by ear.
  final void Function(int index)? onPreviewClip;

  /// Which row the running preview belongs to, or null when nothing plays.
  final int? previewingClip;

  /// Why the last preview could not play, and which row it belongs to.
  final String? previewError;
  final int? previewErrorClip;

  /// The level drawn along each track, when tracks can be shaped over time.
  final List<VolumeEnvelope>? envelopes;

  final void Function(int index, VolumeEnvelope envelope)? onEnvelopeChanged;
  final void Function(int index)? onEnvelopeCleared;

  /// Where a running preview is along each track, for the line across its
  /// lane.
  final ValueListenable<double?> Function(int index)? playheadOf;

  /// Plays or stops the preview from beside any lane, so testing a change
  /// never means scrolling down to the preview card.
  /// Starts or stops the preview of one track on its own.
  final void Function(int index)? onTrackPreview;

  /// Which track is being heard on its own, if any.
  final int? previewingTrack;
  final bool isPreviewPreparing;

  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  VolumeEnvelope _envelopeFor(int index) {
    final List<VolumeEnvelope>? all = envelopes;
    if (all != null && index < all.length) {
      return all[index];
    }
    return VolumeEnvelope.flat;
  }

  /// Selection on the clip at [index], defaulting to the whole file.
  (Duration, Duration) _rangeFor(int index, MediaInfo media) {
    final List<(Duration, Duration)>? ranges = trimRanges;
    if (ranges != null && index < ranges.length) {
      return ranges[index];
    }
    return (Duration.zero, media.duration ?? Duration.zero);
  }

  /// What a row is called.
  ///
  /// On a timeline every clip is an equal step in the sequence; in a mixer the
  /// first track is the one the others sit behind.
  String trackLabel(int index) {
    if (showsPositions) {
      return K.clipNumber.trParams(<String, String>{'number': '${index + 1}'});
    }
    return index == 0
        ? K.mainTrack.tr
        : K.layerNumber.trParams(<String, String>{'number': '${index + 1}'});
  }

  /// This track's own colour, cycled from the same accents the home screen
  /// uses for its tools — so a stack of tracks reads as separate voices
  /// without the mixer inventing a palette of its own.
  Color _accentFor(int index) =>
      AppColors.mixTrackAccents[index % AppColors.mixTrackAccents.length];

  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sources.length,
      onReorderItem: onReorder,
      // The list would otherwise make the whole row a drag target, which
      // fights the selection slider inside it: a press-and-drag there has to
      // move the handle, not the clip. Below, the card says what can be
      // dragged and the slider is left alone.
      buildDefaultDragHandles: false,
      itemBuilder: (BuildContext context, int index) {
        final MediaInfo media = sources[index];
        final Key key = ValueKey<String>('${media.path}#$index');

        // Both tools use a single surface per clip, with controls suited to
        // either volume shaping or sequential trimming.
        if (onEnvelopeChanged
            case final void Function(int, VolumeEnvelope) change) {
          return Padding(
            key: key,
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: MixerTrackCard(
              index: index,
              media: media,
              label: trackLabel(index),
              accent: _accentFor(index),
              envelope: _envelopeFor(index),
              onEnvelopeChanged: (VolumeEnvelope envelope) =>
                  change(index, envelope),
              onEnvelopeCleared: onEnvelopeCleared == null
                  ? null
                  : () => onEnvelopeCleared!(index),
              volume: onVolumeChanged == null
                  ? null
                  : (index < volumes.length ? volumes[index] : 1),
              onVolumeChanged: onVolumeChanged == null
                  ? null
                  : (double value) => onVolumeChanged!(index, value),
              playhead: playheadOf?.call(index),
              isPreviewPlaying: previewingTrack == index,
              isPreviewPreparing:
                  isPreviewPreparing && previewingTrack == index,
              onPreviewToggle: onTrackPreview == null
                  ? null
                  : () => onTrackPreview!(index),
              onRemove: () => onRemove(index),
            ),
          );
        }

        if (showsPositions) {
          return Padding(
            key: key,
            padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
            child: TimelineClipCard(
              index: index,
              media: media,
              range: _rangeFor(index, media),
              start: index < starts.length ? starts[index] : Duration.zero,
              onRemove: () => onRemove(index),
              onTrimChanged: onTrimChanged == null
                  ? null
                  : (Duration start, Duration end) =>
                        onTrimChanged!(index, start, end),
              onPreview: onPreviewClip == null
                  ? null
                  : () => onPreviewClip!(index),
              isPlaying: previewingClip == index,
              errorMessage: previewErrorClip == index
                  ? (previewError ?? '')
                  : '',
            ),
          );
        }

        return Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Press and hold anywhere on the card to move the clip. Keeping
              // the card itself as the target avoids a separate drag glyph
              // competing with the clip number for the small leading space.
              ReorderableDelayedDragStartListener(
                index: index,
                child: SourceSummaryCard(
                  media: media,
                  titleMaxLines: 2,
                  onRemove: () => onRemove(index),
                ),
              ),
              if (onTrimChanged
                  case final void Function(int, Duration, Duration) change)
                _TrimRow(
                  range: _rangeFor(index, media),
                  sourceLength: media.duration ?? Duration.zero,
                  isPlaying: previewingClip == index,
                  errorMessage: previewErrorClip == index
                      ? (previewError ?? '')
                      : '',
                  onChanged: (Duration start, Duration end) =>
                      change(index, start, end),
                  onPreview: onPreviewClip == null
                      ? null
                      : () => onPreviewClip!(index),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Which part of a clip is used, with a way to hear just that part.
class _TrimRow extends StatelessWidget {
  const _TrimRow({
    required this.range,
    required this.sourceLength,
    required this.isPlaying,
    required this.onChanged,
    required this.onPreview,
    required this.errorMessage,
  });

  final (Duration start, Duration end) range;
  final Duration sourceLength;
  final bool isPlaying;
  final String errorMessage;
  final void Function(Duration start, Duration end) onChanged;
  final VoidCallback? onPreview;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Without a readable length there is nothing to select across, so the
    // whole clip is used and no slider is offered.
    if (sourceLength <= Duration.zero) {
      return const SizedBox.shrink();
    }

    final double maxMs = sourceLength.inMilliseconds.toDouble();
    final double startMs = range.$1.inMilliseconds.toDouble().clamp(0, maxMs);
    final double endMs = range.$2.inMilliseconds.toDouble().clamp(
      startMs,
      maxMs,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(K.selectionLabel.tr, style: theme.textTheme.labelMedium),
          RangeSlider(
            min: 0,
            max: maxMs,
            values: RangeValues(startMs, endMs),
            labels: RangeLabels(
              Formatters.duration(Duration(milliseconds: startMs.round())),
              Formatters.duration(Duration(milliseconds: endMs.round())),
            ),
            onChanged: (RangeValues values) => onChanged(
              Duration(milliseconds: values.start.round()),
              Duration(milliseconds: values.end.round()),
            ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '${K.startsAt.trParams(<String, String>{'time': Formatters.duration(Duration(milliseconds: startMs.round()))})}   ${K.endLabel.tr} '
                  '${Formatters.duration(Duration(milliseconds: endMs.round()))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimens.spaceMd,
                    vertical: AppDimens.spaceSm,
                  ),
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  shape: const StadiumBorder(),
                ),
                onPressed: onPreview,
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isPlaying ? K.stop.tr : K.play.tr),
              ),
            ],
          ),
          if (errorMessage.isNotEmpty)
            Text(
              errorMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
