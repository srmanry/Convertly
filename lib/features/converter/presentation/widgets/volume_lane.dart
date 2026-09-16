import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/volume_envelope.dart';

/// One track's level along its length, shaped with points the way a music
/// mixer's automation lane is.
///
/// Higher on the lane is louder at that moment, lower is quieter, and every
/// point shows its level as a percentage. Tap the lane to drop a point, drag a
/// point to move it, or tap one to select it and set it exactly with the
/// buttons underneath. A drag that starts away from every point is left to the
/// page, so scrolling past a lane never changes it by accident.
class VolumeLane extends StatefulWidget {
  const VolumeLane({
    required this.envelope,
    required this.onChanged,
    super.key,
    this.length,
    this.playhead,
    this.accent,
  });

  /// Tall enough to place a point precisely with a thumb.
  static const double laneHeight = 168;

  /// How close a touch has to land to a point to pick it up. Wider than the
  /// drawn point, which a fingertip covers completely.
  static const double grabRadius = 32;

  /// Space on the left for the 0%, 100% and 200% scale.
  static const double padLeft = 42;
  static const double padRight = 18;
  static const double padY = 18;

  /// How far one tap of the − and + buttons moves a point.
  static const double nudgeStep = 0.05;

  final VolumeEnvelope envelope;

  /// Reports the whole new shape after every edit.
  final ValueChanged<VolumeEnvelope> onChanged;

  /// How long the track runs, for the time labels. Null when unknown.
  final Duration? length;

  /// Where a running preview is along this track, 0 to 1, or null.
  final ValueListenable<double?>? playhead;

  /// The colour this track's curve, points and controls are drawn in.
  ///
  /// Null falls back to the theme's primary, so a lane dropped in on its own
  /// still reads correctly; the mixer passes each track its own colour so a
  /// stack of lanes reads as separate voices at a glance.
  final Color? accent;

  @override
  State<VolumeLane> createState() => _VolumeLaneState();
}

class _VolumeLaneState extends State<VolumeLane> {
  int? _selected;

  /// Whether the touched point was already selected, so a tap on it without
  /// moving lets it go again.
  bool _wasSelected = false;
  bool _moved = false;

  /// True while a finger holds a point. The level bubble shows only then:
  /// at rest the controls under the lane already say it, larger.
  bool _dragging = false;

  /// Where the finger sat relative to the point it picked up, so the point
  /// does not jump to the fingertip on the first move.
  Offset _grabOffset = Offset.zero;
  Offset _grabStart = Offset.zero;

  /// The 10% step the dragged point last sat in, for a light tick each time
  /// it crosses into another one.
  int _lastStep = 0;

  VolumeEnvelope get _envelope => widget.envelope;

  @override
  void didUpdateWidget(VolumeLane old) {
    super.didUpdateWidget(old);
    final int? selected = _selected;
    if (selected != null && selected >= _envelope.points.length) {
      _selected = null;
    }
  }

  int? _pointNear(_LaneGeometry geometry, Offset local) {
    int? nearest;
    double best = VolumeLane.grabRadius;
    for (int i = 0; i < _envelope.points.length; i++) {
      final double distance =
          (geometry.offsetOf(_envelope.points[i]) - local).distance;
      // The selected point wins a tie, so it stays easy to keep hold of when
      // two points sit close together.
      if (distance < best || (distance <= best && i == _selected)) {
        best = distance;
        nearest = i;
      }
    }
    return nearest;
  }

  /// Pulls a level onto 100% when it lands close to it, so "back to normal"
  /// is easy to hit exactly with a thumb.
  static double _snap(double level) =>
      (level - VolumeEnvelope.unity).abs() < 0.05
      ? VolumeEnvelope.unity
      : level;

  void _grab(_LaneGeometry geometry, int index, Offset local) {
    HapticFeedback.selectionClick();
    final EnvelopePoint point = _envelope.points[index];
    setState(() {
      _wasSelected = _selected == index;
      _selected = index;
      _dragging = true;
      _moved = false;
      _grabStart = local;
      _grabOffset = geometry.offsetOf(point) - local;
      _lastStep = (point.level * 10).round();
    });
  }

  void _move(_LaneGeometry geometry, Offset local) {
    final int? index = _selected;
    if (index == null) {
      return;
    }
    // A touch that barely moves is a tap to select, not a nudge.
    if (!_moved && (local - _grabStart).distance < 6) {
      return;
    }
    _moved = true;
    final (double position, double rawLevel) = geometry.valueAt(
      local + _grabOffset,
    );
    final double level = _snap(rawLevel);

    final int step = (level * 10).round();
    if (step != _lastStep) {
      _lastStep = step;
      HapticFeedback.selectionClick();
    }
    widget.onChanged(_envelope.withPointMoved(index, position, level));
  }

  void _release() {
    setState(() {
      if (!_moved && _wasSelected) {
        _selected = null;
      }
      _dragging = false;
    });
    _moved = false;
    _wasSelected = false;
  }

  void _addAt(_LaneGeometry geometry, Offset local) {
    if (_pointNear(geometry, local) != null) {
      return;
    }
    if (!_envelope.canAddPoint) {
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'A track can have up to ${VolumeEnvelope.maxPoints} points. '
              'Delete one to add another.',
            ),
          ),
        );
      return;
    }
    final (double position, double level) = geometry.valueAt(local);
    final (VolumeEnvelope next, int? index) = _envelope.withPointAdded(
      position,
      _snap(level),
    );
    if (index == null) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
    widget.onChanged(next);
  }

  void _nudge(double by) {
    final int? index = _selected;
    if (index == null) {
      return;
    }
    final EnvelopePoint point = _envelope.points[index];
    // Lands on whole 5% steps, so repeated taps read as round numbers.
    final double target =
        ((point.level + by) / VolumeLane.nudgeStep).round() *
        VolumeLane.nudgeStep;
    HapticFeedback.selectionClick();
    widget.onChanged(_envelope.withPointMoved(index, point.position, target));
  }

  void _deleteSelected() {
    final int? index = _selected;
    if (index == null || !_envelope.canRemoveAt(index)) {
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _selected = null);
    widget.onChanged(_envelope.withPointRemoved(index));
  }

  String _timeOf(EnvelopePoint point) {
    final Duration? length = widget.length;
    if (length == null || length <= Duration.zero) {
      return '';
    }
    return Formatters.duration(
      Duration(milliseconds: (length.inMilliseconds * point.position).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = widget.accent ?? colors.primary;
    final int? selected =
        _selected != null && _selected! < _envelope.points.length
        ? _selected
        : null;
    final TextStyle labelStyle =
        theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: VolumeLane.laneHeight,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final _LaneGeometry geometry = _LaneGeometry(
                Size(constraints.maxWidth, VolumeLane.laneHeight),
              );

              return RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: <Type, GestureRecognizerFactory>{
                  _PointGrabRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        _PointGrabRecognizer
                      >(_PointGrabRecognizer.new, (
                        _PointGrabRecognizer recognizer,
                      ) {
                        recognizer
                          ..pointAt = ((Offset local) =>
                              _pointNear(geometry, local))
                          ..onGrab = ((int index, Offset local) =>
                              _grab(geometry, index, local))
                          ..onMove = ((Offset local) => _move(geometry, local))
                          ..onRelease = _release;
                      }),
                  TapGestureRecognizer:
                      GestureRecognizerFactoryWithHandlers<
                        TapGestureRecognizer
                      >(TapGestureRecognizer.new, (
                        TapGestureRecognizer recognizer,
                      ) {
                        recognizer.onTapUp = (TapUpDetails details) =>
                            _addAt(geometry, details.localPosition);
                      }),
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: <Widget>[
                      CustomPaint(
                        painter: _VolumeLanePainter(
                          geometry: geometry,
                          envelope: _envelope,
                          selected: selected,
                          selectedTime: selected == null
                              ? ''
                              : _timeOf(_envelope.points[selected]),
                          showBubble: _dragging,
                          accent: accent,
                          colors: colors,
                          textStyle: labelStyle,
                        ),
                      ),
                      if (widget.playhead
                          case final ValueListenable<double?> playhead)
                        IgnorePointer(
                          child: CustomPaint(
                            painter: _PlayheadPainter(
                              geometry: geometry,
                              envelope: _envelope,
                              playhead: playhead,
                              colors: colors,
                              textStyle: labelStyle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppDimens.spaceXs),
        _TimeLabels(length: widget.length),
        const SizedBox(height: AppDimens.spaceSm),
        if (selected != null)
          _PointControls(
            point: _envelope.points[selected],
            time: _timeOf(_envelope.points[selected]),
            canDelete: _envelope.canRemoveAt(selected),
            accent: accent,
            onNudge: _nudge,
            onDelete: _deleteSelected,
          )
        else
          Text(
            _envelope.points.length <= 2
                ? 'Tap the line to add a point. Drag it down for quieter, '
                      'up for louder.'
                : 'Drag a point to change it, or tap one to set it exactly.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

/// Exact controls for the selected point: step it down or up, or delete it.
///
/// A thumb covers the point it drags, so these give a way to land on an exact
/// level without having to see under it.
class _PointControls extends StatelessWidget {
  const _PointControls({
    required this.point,
    required this.time,
    required this.canDelete,
    required this.accent,
    required this.onNudge,
    required this.onDelete,
  });

  final EnvelopePoint point;
  final String time;
  final bool canDelete;
  final Color accent;
  final ValueChanged<double> onNudge;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final int percent = (point.level * 100).round();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceSm,
        vertical: AppDimens.spaceXs,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          accent.withValues(alpha: 0.1),
          colors.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          IconButton.filledTonal(
            tooltip: 'Quieter',
            style: IconButton.styleFrom(foregroundColor: accent),
            onPressed: point.level <= 0
                ? null
                : () => onNudge(-VolumeLane.nudgeStep),
            icon: const Icon(Icons.remove_rounded),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '$percent%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                  ),
                ),
                Text(
                  time.isEmpty ? _describe(percent) : 'at $time',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Louder',
            style: IconButton.styleFrom(foregroundColor: accent),
            onPressed: point.level >= VolumeEnvelope.maxLevel
                ? null
                : () => onNudge(VolumeLane.nudgeStep),
            icon: const Icon(Icons.add_rounded),
          ),
          if (canDelete) ...<Widget>[
            const SizedBox(width: AppDimens.spaceSm),
            IconButton(
              tooltip: 'Delete point',
              onPressed: onDelete,
              color: colors.error,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }

  static String _describe(int percent) {
    if (percent == 100) {
      return 'normal';
    }
    return percent < 100 ? 'quieter' : 'louder';
  }
}

/// Start, middle and end times under the lane.
class _TimeLabels extends StatelessWidget {
  const _TimeLabels({required this.length});

  final Duration? length;

  @override
  Widget build(BuildContext context) {
    final Duration? total = length;
    if (total == null || total <= Duration.zero) {
      return const SizedBox.shrink();
    }
    final TextStyle? style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: const EdgeInsets.only(
        left: VolumeLane.padLeft - 10,
        right: VolumeLane.padRight - 10,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(Formatters.duration(Duration.zero), style: style),
          Text(
            Formatters.duration(
              Duration(milliseconds: total.inMilliseconds ~/ 2),
            ),
            style: style,
          ),
          Text(Formatters.duration(total), style: style),
        ],
      ),
    );
  }
}

/// Where points sit inside the lane, shared by the painters and the gestures
/// so a point is grabbed exactly where it is drawn.
class _LaneGeometry {
  const _LaneGeometry(this.size);

  final Size size;

  Rect get area => Rect.fromLTRB(
    VolumeLane.padLeft,
    VolumeLane.padY,
    math.max(VolumeLane.padLeft, size.width - VolumeLane.padRight),
    math.max(VolumeLane.padY, size.height - VolumeLane.padY),
  );

  double xOf(double position) => area.left + area.width * position;

  double yOf(double level) =>
      area.bottom -
      area.height * (level / VolumeEnvelope.maxLevel).clamp(0.0, 1.0);

  Offset offsetOf(EnvelopePoint point) =>
      Offset(xOf(point.position), yOf(point.level));

  (double position, double level) valueAt(Offset local) {
    final Rect rect = area;
    final double position = rect.width <= 0
        ? 0
        : ((local.dx - rect.left) / rect.width).clamp(0.0, 1.0);
    final double level = rect.height <= 0
        ? VolumeEnvelope.unity
        : ((rect.bottom - local.dy) / rect.height).clamp(0.0, 1.0) *
              VolumeEnvelope.maxLevel;
    return (position, level);
  }
}

/// Picks up a point the moment a finger lands on it.
///
/// Claiming the touch straight away is what stops the page's scroll from
/// taking a vertical drag on a point. A touch that lands away from every
/// point is never claimed, so it scrolls, or becomes a tap.
class _PointGrabRecognizer extends OneSequenceGestureRecognizer {
  int? Function(Offset local)? pointAt;
  void Function(int index, Offset local)? onGrab;
  void Function(Offset local)? onMove;
  VoidCallback? onRelease;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    final int? index = pointAt?.call(event.localPosition);
    if (index == null) {
      return;
    }
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
    onGrab?.call(index, event.localPosition);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onMove?.call(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      onRelease?.call();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'volume point grab';
}

/// Black or white, whichever reads on [background].
Color _readableOn(Color background) =>
    ThemeData.estimateBrightnessForColor(background) == Brightness.dark
    ? Colors.white
    : Colors.black87;

void _paintText(
  Canvas canvas,
  String text,
  TextStyle style, {
  required Offset anchor,
  required Size bounds,
  Alignment align = Alignment.center,
}) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double left = (anchor.dx - painter.width * (align.x + 1) / 2).clamp(
    0.0,
    math.max(0.0, bounds.width - painter.width),
  );
  final double top = anchor.dy - painter.height * (align.y + 1) / 2;
  painter.paint(canvas, Offset(left, top));
}

class _VolumeLanePainter extends CustomPainter {
  const _VolumeLanePainter({
    required this.geometry,
    required this.envelope,
    required this.selected,
    required this.selectedTime,
    required this.showBubble,
    required this.accent,
    required this.colors,
    required this.textStyle,
  });

  final _LaneGeometry geometry;
  final VolumeEnvelope envelope;
  final int? selected;
  final String selectedTime;
  final bool showBubble;

  /// This track's own colour, for the curve, its points and their labels.
  /// Everything else — the grid, the scale, the resting line — stays neutral
  /// so a stack of differently coloured lanes still reads as one system.
  final Color accent;
  final ColorScheme colors;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect area = geometry.area;
    if (area.width <= 0 || envelope.points.length < 2) {
      return;
    }

    _paintGrid(canvas, size, area);

    // Sampled finely enough to look smooth at any lane width.
    final Path curve = Path();
    final int steps = math.max(24, (area.width / 3).round());
    for (int i = 0; i <= steps; i++) {
      final double position = i / steps;
      final Offset at = Offset(
        geometry.xOf(position),
        geometry.yOf(envelope.levelAt(position)),
      );
      if (i == 0) {
        curve.moveTo(at.dx, at.dy);
      } else {
        curve.lineTo(at.dx, at.dy);
      }
    }

    final Path fill = Path.from(curve)
      ..lineTo(area.right, area.bottom)
      ..lineTo(area.left, area.bottom)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            accent.withValues(alpha: 0.38),
            accent.withValues(alpha: 0.04),
          ],
        ).createShader(area),
    );

    canvas.drawPath(
      curve,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final TextStyle valueStyle = textStyle.copyWith(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: colors.onSurface,
    );
    double lastLabelX = double.negativeInfinity;
    for (int i = 0; i < envelope.points.length; i++) {
      final Offset at = geometry.offsetOf(envelope.points[i]);
      if (i == selected) {
        continue;
      }
      _paintPoint(canvas, at, false);
      // Labels that would collide are skipped rather than stacked; the level
      // of any point is always one tap away.
      if (at.dx - lastLabelX >= 34) {
        lastLabelX = at.dx;
        _paintValue(canvas, size, at, envelope.points[i].level, valueStyle);
      }
    }

    final int? active = selected;
    if (active != null && active < envelope.points.length) {
      final EnvelopePoint point = envelope.points[active];
      final Offset at = geometry.offsetOf(point);
      _paintPoint(canvas, at, true);
      final String percent = '${(point.level * 100).round()}%';
      if (showBubble) {
        _paintBubble(
          canvas,
          size,
          at,
          selectedTime.isEmpty ? percent : '$selectedTime · $percent',
        );
      } else {
        _paintValue(canvas, size, at, point.level, valueStyle);
      }
    }
  }

  void _paintGrid(Canvas canvas, Size size, Rect area) {
    final Paint faint = Paint()
      ..color = colors.outlineVariant.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    for (final double fraction in <double>[0.25, 0.5, 0.75]) {
      final double x = area.left + area.width * fraction;
      canvas.drawLine(Offset(x, area.top), Offset(x, area.bottom), faint);
    }
    for (final double level in <double>[0, 0.5, 1.5, 2]) {
      final double y = geometry.yOf(level);
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), faint);
    }

    // The resting line, dashed, so "louder" and "quieter" read as above and
    // below normal rather than as absolute heights.
    final double restingY = geometry.yOf(VolumeEnvelope.unity);
    final Paint resting = Paint()
      ..color = colors.outline.withValues(alpha: 0.75)
      ..strokeWidth = 1.2;
    for (double x = area.left; x < area.right; x += 8) {
      canvas.drawLine(
        Offset(x, restingY),
        Offset(math.min(x + 4, area.right), restingY),
        resting,
      );
    }

    final TextStyle scale = textStyle.copyWith(
      fontSize: 10,
      color: colors.onSurfaceVariant,
    );
    for (final (double level, String text) in <(double, String)>[
      (2, '200%'),
      (1, '100%'),
      (0, '0%'),
    ]) {
      _paintText(
        canvas,
        text,
        scale,
        anchor: Offset(area.left - 8, geometry.yOf(level)),
        bounds: size,
        align: Alignment.centerRight,
      );
    }
  }

  void _paintValue(
    Canvas canvas,
    Size size,
    Offset at,
    double level,
    TextStyle style,
  ) {
    // Above the point, or below it when it sits against the top.
    final bool below = at.dy - 22 < 0;
    _paintText(
      canvas,
      '${(level * 100).round()}%',
      style,
      anchor: Offset(at.dx, below ? at.dy + 12 : at.dy - 12),
      bounds: size,
      align: below ? Alignment.topCenter : Alignment.bottomCenter,
    );
  }

  void _paintPoint(Canvas canvas, Offset at, bool isSelected) {
    if (isSelected) {
      canvas.drawCircle(at, 20, Paint()..color = accent.withValues(alpha: 0.2));
      canvas.drawCircle(at, 10, Paint()..color = accent);
      canvas.drawCircle(
        at,
        10,
        Paint()
          ..color = _readableOn(accent)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      return;
    }
    canvas.drawCircle(at, 8, Paint()..color = colors.surface);
    canvas.drawCircle(
      at,
      8,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
  }

  void _paintBubble(Canvas canvas, Size size, Offset at, String text) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(
          color: colors.onInverseSurface,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    const double padH = 10;
    const double padV = 5;
    final double width = painter.width + padH * 2;
    final double height = painter.height + padV * 2;
    final double left = (at.dx - width / 2).clamp(
      0.0,
      math.max(0.0, size.width - width),
    );
    // Above the point, clear of the fingertip, unless that would leave the
    // lane.
    final double top = at.dy - 26 - height >= 0
        ? at.dy - 26 - height
        : at.dy + 26;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        const Radius.circular(8),
      ),
      Paint()..color = colors.inverseSurface,
    );
    painter.paint(canvas, Offset(left + padH, top + padV));
  }

  @override
  bool shouldRepaint(_VolumeLanePainter old) =>
      old.envelope != envelope ||
      old.selected != selected ||
      old.selectedTime != selectedTime ||
      old.showBubble != showBubble ||
      old.accent != accent ||
      old.colors != colors ||
      old.geometry.size != geometry.size;
}

/// The line that runs across the lane while the preview plays, with the level
/// being heard at that moment.
///
/// Painted on its own layer, driven straight by the preview, so it moves many
/// times a second without rebuilding the lane or the page around it.
class _PlayheadPainter extends CustomPainter {
  _PlayheadPainter({
    required this.geometry,
    required this.envelope,
    required this.playhead,
    required this.colors,
    required this.textStyle,
  }) : super(repaint: playhead);

  final _LaneGeometry geometry;
  final VolumeEnvelope envelope;
  final ValueListenable<double?> playhead;
  final ColorScheme colors;
  final TextStyle textStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final double? value = playhead.value;
    final Rect area = geometry.area;
    if (value == null || value < 0 || value > 1 || area.width <= 0) {
      return;
    }

    final double x = geometry.xOf(value);
    final double level = envelope.levelAt(value);
    final Offset onCurve = Offset(x, geometry.yOf(level));

    canvas.drawLine(
      Offset(x, 2),
      Offset(x, size.height - 2),
      Paint()
        ..color = colors.tertiary
        ..strokeWidth = 2,
    );
    canvas.drawCircle(onCurve, 6, Paint()..color = colors.tertiary);
    canvas.drawCircle(
      onCurve,
      6,
      Paint()
        ..color = colors.onTertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // The level being heard right now, pinned to the bottom of the line so it
    // stays out of the way of the points above.
    final TextPainter label = TextPainter(
      text: TextSpan(
        text: '${(level * 100).round()}%',
        style: textStyle.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: colors.onTertiary,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final double width = label.width + 10;
    final double height = label.height + 4;
    final double left = (x - width / 2).clamp(
      0.0,
      math.max(0.0, size.width - width),
    );
    final double top = size.height - height - 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, height),
        const Radius.circular(6),
      ),
      Paint()..color = colors.tertiary,
    );
    label.paint(canvas, Offset(left + 5, top + 2));
  }

  @override
  bool shouldRepaint(_PlayheadPainter old) =>
      old.playhead != playhead ||
      old.envelope != envelope ||
      old.colors != colors ||
      old.geometry.size != geometry.size;
}
