import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/entities/volume_envelope.dart';
import 'source_summary_card.dart';
import 'volume_lane.dart';

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
    this.previewError,
    this.previewErrorClip,
    this.envelopes,
    this.onEnvelopePoint,
    this.onEnvelopeCleared,
    this.longestClip,
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

  final void Function(int index, int point, double level)? onEnvelopePoint;
  final void Function(int index)? onEnvelopeCleared;

  /// Length of the longest track, used to draw a shorter one shorter.
  final Duration? longestClip;

  final void Function(int index) onRemove;
  final void Function(int oldIndex, int newIndex) onReorder;

  VolumeEnvelope _envelopeFor(int index) {
    final List<VolumeEnvelope>? all = envelopes;
    if (all != null && index < all.length) {
      return all[index];
    }
    return VolumeEnvelope.flat;
  }

  /// How much of the row [media] fills, so length is readable at a glance.
  double _widthFactorFor(MediaInfo media) {
    final Duration? longest = longestClip;
    final Duration? own = media.duration;
    if (longest == null || own == null || longest <= Duration.zero) {
      return 1;
    }
    return own.inMilliseconds / longest.inMilliseconds;
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
      return 'Clip ${index + 1}';
    }
    return index == 0 ? 'Main track' : 'Layer ${index + 1}';
  }

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

        return Padding(
          key: ValueKey<String>('${media.path}#$index'),
          padding: const EdgeInsets.only(bottom: AppDimens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Press and hold anywhere on the card to move the clip; the
              // handle picks it up straight away for anyone who finds it.
              ReorderableDelayedDragStartListener(
                index: index,
                child: SourceSummaryCard(
                  media: media,
                  onRemove: () => onRemove(index),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimens.spaceSm,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.drag_handle_rounded),
                          if (showsPositions) ...<Widget>[
                            const SizedBox(width: AppDimens.spaceSm),
                            _ClipNumber(index: index),
                          ],
                        ],
                      ),
                    ),
                  ),
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
              if (showsPositions)
                _PlaysRow(
                  start: index < starts.length ? starts[index] : Duration.zero,
                  clipLength: index < starts.length
                      ? _rangeFor(index, media).$2 - _rangeFor(index, media).$1
                      : media.duration,
                ),
              if (onEnvelopePoint
                  case final void Function(int, int, double) change)
                _ShapeRow(
                  label: trackLabel(index),
                  envelope: _envelopeFor(index),
                  widthFactor: _widthFactorFor(media),
                  onPointChanged: (int point, double level) =>
                      change(index, point, level),
                  onCleared: onEnvelopeCleared == null
                      ? null
                      : () => onEnvelopeCleared!(index),
                ),
              if (onVolumeChanged case final void Function(int, double) change)
                _VolumeRow(
                  label: trackLabel(index),
                  volume: index < volumes.length ? volumes[index] : 1,
                  onChanged: (double value) => change(index, value),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The clip's position in the sequence, coloured to match its block.
class _ClipNumber extends StatelessWidget {
  const _ClipNumber({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool isEven = index.isEven;

    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isEven ? colors.primary : colors.tertiary,
        shape: BoxShape.circle,
      ),
      child: Text(
        '${index + 1}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: isEven ? colors.onPrimary : colors.onTertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
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
          Text('Selection', style: theme.textTheme.labelMedium),
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
                  'Start ${Formatters.duration(Duration(milliseconds: startMs.round()))}'
                  '   End ${Formatters.duration(Duration(milliseconds: endMs.round()))}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: onPreview,
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                ),
                label: Text(isPlaying ? 'Stop' : 'Play'),
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

/// When this clip plays within the finished track.
class _PlaysRow extends StatelessWidget {
  const _PlaysRow({required this.start, required this.clipLength});

  final Duration start;
  final Duration? clipLength;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Duration? end = clipLength == null ? null : start + clipLength!;
    if (end == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            size: AppDimens.iconSm,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimens.spaceSm),
          Text(
            'Plays ${Formatters.duration(start)}'
            ' – ${Formatters.duration(end)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A track's level along its length, with a way back to an even one.
class _ShapeRow extends StatelessWidget {
  const _ShapeRow({
    required this.label,
    required this.envelope,
    required this.widthFactor,
    required this.onPointChanged,
    required this.onCleared,
  });

  final String label;
  final VolumeEnvelope envelope;
  final double widthFactor;
  final void Function(int point, double level) onPointChanged;
  final VoidCallback? onCleared;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(child: Text(label, style: theme.textTheme.labelMedium)),
              if (onCleared != null && !envelope.isFlat)
                TextButton(onPressed: onCleared, child: const Text('Even out')),
            ],
          ),
          VolumeLane(
            envelope: envelope,
            widthFactor: widthFactor,
            onPointChanged: onPointChanged,
          ),
        ],
      ),
    );
  }
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.label,
    required this.volume,
    required this.onChanged,
  });

  final String label;
  final double volume;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double clamped = volume.clamp(0, MixTrackList.maxVolume);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.spaceSm),
      child: Row(
        children: <Widget>[
          Text(label, style: theme.textTheme.bodySmall),
          Expanded(
            child: Slider(
              min: 0,
              max: MixTrackList.maxVolume,
              // One step per 5%, fine enough to place a background layer
              // without the slider feeling loose.
              divisions: 40,
              value: clamped,
              label: _percent(clamped),
              onChanged: onChanged,
            ),
          ),
          SizedBox(
            width: 48,
            child: Text(
              _percent(clamped),
              textAlign: TextAlign.end,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _percent(double volume) => '${(volume * 100).round()}%';
}
