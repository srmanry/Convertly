import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/theme/app_colors.dart';
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
    final bool isDark = theme.brightness == Brightness.dark;

    if (clips.isEmpty || totalMs <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          height: stripHeight,
          // A square, borderless ribbon keeps the waveform continuous. The
          // soft light in the gradient provides separation from the page
          // without drawing a frame around it.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color.alphaBlend(
                  Colors.white.withValues(alpha: isDark ? 0.065 : 0.32),
                  theme.colorScheme.surfaceContainerHighest,
                ),
                Color.alphaBlend(
                  theme.colorScheme.primary.withValues(
                    alpha: isDark ? 0.07 : 0.04,
                  ),
                  theme.colorScheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;

              return Stack(
                children: <Widget>[
                  Positioned(
                    left: 0,
                    right: 0,
                    top: (stripHeight - 1) / 2,
                    height: 1,
                    child: ColoredBox(
                      color: Colors.white.withValues(
                        alpha: isDark ? 0.12 : 0.42,
                      ),
                    ),
                  ),
                  for (int index = 0; index < clips.length; index++)
                    _block(index, width, totalMs),
                  if (playhead case final Duration position)
                    _playhead(theme, position, width, totalMs),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              '0:00',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              Formatters.duration(total),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _block(int index, double width, int totalMs) {
    final TimelineClip clip = clips[index];
    // Cycled from the same accents the mixer gives each of its tracks, so a
    // clip reads as its own voice here too, rather than just alternating
    // between two theme colours.
    final Color color =
        AppColors.mixTrackAccents[index % AppColors.mixTrackAccents.length];
    final double left = width * clip.start.inMilliseconds / totalMs;
    final double blockWidth = (width * clip.length.inMilliseconds / totalMs)
        .clamp(minimumBlockWidth, width);

    return Positioned(
      left: left.clamp(0, width),
      top: 0,
      bottom: 0,
      width: blockWidth,
      // No fill or separator behind a clip: the strip's background carries
      // through every block, so it reads as one continuous waveform ribbon.
      child: DecoratedBox(
        key: blockKey(index),
        decoration: const BoxDecoration(),
        // Too narrow for the bars to read as anything but noise; the number
        // badge alone ties a sliver of a clip to its card.
        child: blockWidth < 16
            ? null
            : CustomPaint(
                painter: _WaveformTexturePainter(
                  color: color,
                  seed: Object.hash(index, clip.label),
                ),
                child: blockWidth < 22
                    // Too narrow for the badge too.
                    ? null
                    : Center(
                        child: _ClipBadge(label: clip.label, color: color),
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

/// A decorative waveform, standing in for the clip's real one.
///
/// This is texture, not a reading of the audio: it fills what would
/// otherwise be a flat block, in the same shape a real waveform takes,
/// without claiming to show this clip's actual levels.
class _WaveformTexturePainter extends CustomPainter {
  const _WaveformTexturePainter({required this.color, required this.seed});

  static const double _barWidth = 3;
  static const double _gap = 2.5;

  final Color color;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final math.Random random = math.Random(seed);
    final Paint glow = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final Paint paint = Paint()..color = color.withValues(alpha: 0.95);
    final double middle = size.height / 2;

    for (double x = 2; x < size.width - _barWidth; x += _barWidth + _gap) {
      final double reach = 0.2 + random.nextDouble() * 0.65;
      final double barHeight = (size.height * reach).clamp(2.0, size.height);
      final RRect bar = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, middle - barHeight / 2, _barWidth, barHeight),
        const Radius.circular(1.5),
      );
      canvas
        ..drawRRect(bar, glow)
        ..drawRRect(bar, paint);
    }
  }

  @override
  bool shouldRepaint(_WaveformTexturePainter old) =>
      old.color != color || old.seed != seed;
}

/// The clip's number, small and solid, so it stays readable over the bars
/// behind it regardless of how the waveform texture happens to fall there.
class _ClipBadge extends StatelessWidget {
  const _ClipBadge({required this.label, required this.color});

  static const double _size = 22;

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color.alphaBlend(Colors.black.withValues(alpha: 0.22), color),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
