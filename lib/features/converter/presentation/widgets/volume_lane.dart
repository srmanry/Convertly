import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../domain/entities/volume_envelope.dart';

/// One track's level drawn along its own length, and reshaped by dragging.
///
/// Dragging up at a point makes the track louder there than it would otherwise
/// be, down makes it quieter, and the resting line across the middle leaves it
/// as it is. Dragging sideways draws through the points it passes, so a whole
/// dip is one gesture rather than a point at a time.
class VolumeLane extends StatelessWidget {
  const VolumeLane({
    required this.envelope,
    required this.onPointChanged,
    super.key,
    this.widthFactor = 1,
  });

  /// Tall enough to aim inside with a finger without crowding the track list.
  static const double laneHeight = 72;

  final VolumeEnvelope envelope;

  /// Reports one point's new level, between 0 and [VolumeEnvelope.maxLevel].
  final void Function(int point, double level) onPointChanged;

  /// How much of the row this track fills, so a short track next to a long one
  /// is visibly shorter rather than being stretched to match.
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: laneHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: widthFactor.clamp(0.02, 1),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              void report(Offset position) {
                final double width = constraints.maxWidth;
                if (width <= 0) {
                  return;
                }
                final int point =
                    ((position.dx / width) * (envelope.levels.length - 1))
                        .round()
                        .clamp(0, envelope.levels.length - 1);
                // The top of the lane is the loudest, so the vertical axis is
                // read upside down relative to the screen.
                final double fraction =
                    1 - (position.dy / constraints.maxHeight).clamp(0.0, 1.0);
                onPointChanged(point, fraction * VolumeEnvelope.maxLevel);
              }

              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanDown: (DragDownDetails d) => report(d.localPosition),
                onPanUpdate: (DragUpdateDetails d) => report(d.localPosition),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: CustomPaint(
                    painter: _VolumeLanePainter(
                      envelope: envelope,
                      line: colors.primary,
                      fill: colors.primary.withValues(alpha: 0.18),
                      resting: colors.outlineVariant,
                    ),
                    size: Size.infinite,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _VolumeLanePainter extends CustomPainter {
  const _VolumeLanePainter({
    required this.envelope,
    required this.line,
    required this.fill,
    required this.resting,
  });

  final VolumeEnvelope envelope;
  final Color line;
  final Color fill;
  final Color resting;

  @override
  void paint(Canvas canvas, Size size) {
    final List<double> levels = envelope.levels;
    if (levels.length < 2 || size.width <= 0) {
      return;
    }

    // Where an untouched track sits. Drawn so "louder" and "quieter" are
    // readable as above and below a line rather than as absolute heights.
    final double restingY =
        size.height * (1 - VolumeEnvelope.unity / VolumeEnvelope.maxLevel);
    canvas.drawLine(
      Offset(0, restingY),
      Offset(size.width, restingY),
      Paint()
        ..color = resting
        ..strokeWidth = 1,
    );

    final Path shape = Path();
    for (int i = 0; i < levels.length; i++) {
      final double x = size.width * i / (levels.length - 1);
      final double y =
          size.height *
          (1 - (levels[i] / VolumeEnvelope.maxLevel).clamp(0.0, 1.0));
      if (i == 0) {
        shape.moveTo(x, y);
      } else {
        shape.lineTo(x, y);
      }
    }

    // The band between the drawn line and the resting line is what shows at a
    // glance where the track is pushed up and where it is pulled down.
    final Path band = Path.from(shape)
      ..lineTo(size.width, restingY)
      ..lineTo(0, restingY)
      ..close();
    canvas.drawPath(band, Paint()..color = fill);

    canvas.drawPath(
      shape,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_VolumeLanePainter old) =>
      old.envelope != envelope ||
      old.line != line ||
      old.fill != fill ||
      old.resting != resting;
}
