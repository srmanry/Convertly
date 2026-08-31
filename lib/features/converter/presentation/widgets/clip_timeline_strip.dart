import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';

/// One clip's place on the timeline.
class TimelineClip {
  const TimelineClip({
    required this.label,
    required this.start,
    required this.length,
  });

  final String label;
  final Duration start;
  final Duration length;

  Duration get end => start + length;
}

/// The whole track drawn end to end, one block per clip.
///
/// Clips are positioned by their real start time rather than laid out in
/// order, so a gap shows as background and two clips that overlap are drawn
/// over each other. That keeps the picture honest about what will be
/// exported instead of implying a neat sequence that is not there.
///
/// Block widths are proportional to length, so the strip also shows which
/// clip is the long one at a glance. Neighbouring blocks touch, because
/// playback runs from one straight into the next.
class ClipTimelineStrip extends StatelessWidget {
  const ClipTimelineStrip({
    required this.clips,
    required this.total,
    super.key,
    this.playhead,
  });

  /// Height of the block row. Tall enough to read a number inside a block.
  static const double stripHeight = 56;

  /// A block never gets thinner than this, so a very short clip beside a long
  /// one still shows up rather than collapsing to nothing.
  static const double minimumBlockWidth = 6;

  /// Identifies the block drawn for the clip at [index].
  ///
  /// A narrow block carries no label, so this is what lets its position be
  /// checked without depending on text that may not be rendered.
  static ValueKey<String> blockKey(int index) =>
      ValueKey<String>('timeline-block-$index');

  final List<TimelineClip> clips;
  final Duration total;

  /// Where playback has reached, when a preview is running.
  final Duration? playhead;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int totalMs = total.inMilliseconds;

    if (clips.isEmpty || totalMs <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          child: Container(
            height: stripHeight,
            // The background is what a gap between two clips looks like: no
            // block, so nothing plays there.
            color: theme.colorScheme.surfaceContainerHighest,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;

                return Stack(
                  children: <Widget>[
                    for (int index = 0; index < clips.length; index++)
                      _block(theme, index, width, totalMs),
                    if (playhead case final Duration position)
                      _playhead(theme, position, width, totalMs),
                  ],
                );
              },
            ),
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text('0:00', style: theme.textTheme.bodySmall),
            Text(Formatters.duration(total), style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _block(ThemeData theme, int index, double width, int totalMs) {
    final TimelineClip clip = clips[index];
    // Two theme colours alternating: enough to tell one block from the next
    // without turning the strip into a colour chart, and it follows light and
    // dark on its own.
    final bool isEven = index.isEven;
    final Color color = isEven
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;
    final Color labelColor = isEven
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onTertiary;
    final double left = width * clip.start.inMilliseconds / totalMs;
    final double blockWidth = (width * clip.length.inMilliseconds / totalMs)
        .clamp(minimumBlockWidth, width);

    return Positioned(
      left: left.clamp(0, width),
      top: 0,
      bottom: 0,
      width: blockWidth,
      child: Container(
        key: blockKey(index),
        // No margin and no rounding: clips run straight into each other, so
        // the strip has to look like one continuous track rather than a row
        // of separate tiles. The alternating colour is what marks the join.
        color: color,
        alignment: Alignment.center,
        child: blockWidth < 22
            // Too narrow for a number; the colour alone ties it to its card.
            ? const SizedBox.shrink()
            : Text(
                clip.label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }

  Widget _playhead(
    ThemeData theme,
    Duration position,
    double width,
    int totalMs,
  ) {
    final double left = (width * position.inMilliseconds / totalMs).clamp(
      0,
      width - 2,
    );

    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: 2,
      child: ColoredBox(color: theme.colorScheme.onSurface),
    );
  }
}
