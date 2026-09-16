import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/media_info.dart';
import '../../domain/entities/volume_envelope.dart';
import 'volume_lane.dart';

/// One mixer track, as a single card: who it is, its shape over time, and
/// its base level, all in a colour that is this track's own — so a stack of
/// them reads as separate voices rather than a wall of identical rows.
class MixerTrackCard extends StatelessWidget {
  const MixerTrackCard({
    required this.index,
    required this.media,
    required this.label,
    required this.accent,
    required this.envelope,
    required this.onEnvelopeChanged,
    required this.onRemove,
    super.key,
    this.onEnvelopeCleared,
    this.volume,
    this.onVolumeChanged,
    this.playhead,
    this.isPreviewPlaying = false,
    this.isPreviewPreparing = false,
    this.onPreviewToggle,
  });

  /// The clip's place in the mix, from zero.
  final int index;
  final MediaInfo media;

  /// "Main track" or "Layer N": which role this track plays in the mix.
  final String label;

  /// This track's own colour, threaded through its chart and its controls
  /// so it reads as one voice among the others in the list.
  final Color accent;

  final VolumeEnvelope envelope;
  final ValueChanged<VolumeEnvelope> onEnvelopeChanged;
  final VoidCallback? onEnvelopeCleared;

  /// The track's overall gain, when a flat level on top of its shape is
  /// offered. Null hides the control rather than showing one that does
  /// nothing.
  final double? volume;
  final ValueChanged<double>? onVolumeChanged;

  /// Where a running preview is along this track, for the line across its
  /// chart.
  final ValueListenable<double?>? playhead;
  final bool isPreviewPlaying;
  final bool isPreviewPreparing;

  /// Plays or stops the whole mix from this card, so testing a change never
  /// means scrolling to find the preview button.
  final VoidCallback? onPreviewToggle;

  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final bool canReset = onEnvelopeCleared != null && !envelope.isFlat;

    return Stack(
      // The remove button sits half outside the card, at its corner, so
      // nothing has to be clipped to make room for it.
      clipBehavior: Clip.none,
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppDimens.spaceLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Press and hold the header to pick the card up; the chart
                // below is left alone; a drag started there has to shape the
                // line, not reorder the track.
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              <String>[
                                media.name,
                                if (media.duration case final Duration duration)
                                  Formatters.duration(duration),
                              ].join('  ·  '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canReset)
                        IconButton(
                          tooltip: 'Reset to 100%',
                          visualDensity: VisualDensity.compact,
                          onPressed: onEnvelopeCleared,
                          icon: const Icon(Icons.restart_alt_rounded),
                        ),
                      if (onPreviewToggle != null) ...<Widget>[
                        const SizedBox(width: AppDimens.spaceXs),
                        _PreviewPill(
                          accent: accent,
                          playing: isPreviewPlaying,
                          preparing: isPreviewPreparing,
                          onPressed: onPreviewToggle,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimens.spaceMd),
                VolumeLane(
                  envelope: envelope,
                  length: media.duration,
                  playhead: playhead,
                  accent: accent,
                  onChanged: onEnvelopeChanged,
                ),
                if (onVolumeChanged
                    case final ValueChanged<double> change) ...<Widget>[
                  const SizedBox(height: AppDimens.spaceSm),
                  _BaseLevelRow(
                    volume: volume ?? 1,
                    accent: accent,
                    onChanged: change,
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          top: -8,
          right: -8,
          child: _CornerRemoveButton(onPressed: onRemove),
        ),
      ],
    );
  }
}

/// The remove button, raised at the card's corner rather than sitting in its
/// header — so it reads as detaching the whole card, not as one more control
/// among the row it used to share with Preview and Reset.
class _CornerRemoveButton extends StatelessWidget {
  const _CornerRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Remove',
      child: Material(
        color: colors.surfaceContainerHighest,
        shape: CircleBorder(side: BorderSide(color: colors.outlineVariant)),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(
              Icons.close_rounded,
              size: 16,
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// Plays or stops the whole mix, tinted to this one track's colour so it
/// reads as belonging to this card rather than as a stray control.
class _PreviewPill extends StatelessWidget {
  const _PreviewPill({
    required this.accent,
    required this.playing,
    required this.preparing,
    required this.onPressed,
  });

  final Color accent;
  final bool playing;
  final bool preparing;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Material(
      color: accent.withValues(alpha: isDark ? 0.22 : 0.14),
      borderRadius: BorderRadius.circular(AppDimens.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        onTap: preparing ? null : onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceSm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (preparing)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Icon(
                  playing ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  size: 16,
                  color: accent,
                ),
              const SizedBox(width: AppDimens.spaceXs),
              Text(
                playing ? 'Stop' : 'Preview',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The track's flat level underneath its shape — the same gain a mixer's
/// channel fader sets before automation is layered on top of it.
class _BaseLevelRow extends StatelessWidget {
  const _BaseLevelRow({
    required this.volume,
    required this.accent,
    required this.onChanged,
  });

  /// Loudest the base level can be pushed. Above this the limiter is doing
  /// more work than the slider is, so it stops here.
  static const double maxVolume = 2;

  final double volume;
  final Color accent;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double clamped = volume.clamp(0, maxVolume);
    final String percent = '${(clamped * 100).round()}%';

    return Row(
      children: <Widget>[
        Icon(
          Icons.tune_rounded,
          size: AppDimens.iconSm,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: AppDimens.spaceSm),
        Text(
          'Base level',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: accent,
              thumbColor: accent,
              overlayColor: accent.withValues(alpha: 0.12),
            ),
            child: Slider(
              min: 0,
              max: maxVolume,
              // One step per 5%, fine enough to place a background layer
              // without the slider feeling loose.
              divisions: 40,
              value: clamped,
              label: percent,
              onChanged: onChanged,
            ),
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            percent,
            textAlign: TextAlign.end,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
