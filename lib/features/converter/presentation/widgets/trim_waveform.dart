import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../../core/constants/app_dimens.dart';

/// The waveform the user drags a selection out of.
///
/// The bars are the real shape of the track, decoded from the audio itself.
/// That is the whole point of showing them: the user aims the handles at a
/// gap or a beat they can see, so a decorative or invented waveform would be
/// worse than none — it would send them to the wrong place with confidence.
class TrimWaveform extends StatefulWidget {
  const TrimWaveform({
    required this.peaks,
    required this.total,
    required this.start,
    required this.end,
    required this.onChanged,
    super.key,
    this.accent,
    this.playhead,
    this.isPlaying = false,
    this.isLoading = false,
    this.speed = 1,
  });

  /// Bar heights in the range 0..1, left to right. Empty while the audio is
  /// still being read.
  final List<double> peaks;

  final Duration total;
  final Duration start;
  final Duration end;
  final void Function(Duration start, Duration end) onChanged;
  final Color? accent;

  /// Where the preview has reached, measured from the start of the track.
  /// Null when nothing is playing.
  final Duration? playhead;

  final bool isPlaying;

  /// True while the track is still being decoded, when there is no shape to
  /// draw yet.
  final bool isLoading;

  /// Rate the preview runs at, so the sweep between position reports keeps
  /// pace with what is being heard.
  final double speed;

  /// Shortest selection a drag may leave behind, so the two handles cannot be
  /// pushed through each other into an empty clip.
  static const Duration minimumSelection = Duration(milliseconds: 500);

  /// How far a finger may land from a handle and still grab it.
  static const double _grabRadius = 28;

  /// Blank margin kept at each end of the track.
  ///
  /// Without it a handle parked at 0% or 100% sits half outside the widget:
  /// its cap is clipped, and half its touch target is unreachable — exactly
  /// the positions a handle starts in.
  static const double edgeInset = 12;

  @override
  State<TrimWaveform> createState() => _TrimWaveformState();
}

enum _Handle { start, end }

/// Touch-target width of a handle's accessibility node.
const double _semanticsWidth = 44;

/// Width one bar occupies, gap included. Wide enough that the bars read as
/// bars rather than as a fill.
const double _barSlot = 4.5;

class _TrimWaveformState extends State<TrimWaveform>
    with SingleTickerProviderStateMixin {
  _Handle? _dragging;
  double _trackWidth = 0;

  /// The player reports its position a few times a second. Drawing only those
  /// reports makes the playhead hop; this carries it between them at the rate
  /// the audio is running, and re-anchors on every real report so it can
  /// never drift away from the sound.
  ///
  /// Created eagerly rather than lazily: a `late` ticker that never played
  /// would be built for the first time inside dispose, on an element that is
  /// already gone, and leaving the screen without previewing would throw.
  late final Ticker _ticker;
  Duration _anchorPlayhead = Duration.zero;
  Duration _anchorElapsed = Duration.zero;
  Duration _sweptPlayhead = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _anchorPlayhead = widget.playhead ?? Duration.zero;
    _sweptPlayhead = _anchorPlayhead;
    if (_wantsFrames) {
      _ticker.start();
    }
  }

  /// Frames are needed while something is moving: the playhead sweeping, or
  /// the placeholder running during a decode.
  bool get _wantsFrames => widget.isPlaying || widget.isLoading;

  @override
  void didUpdateWidget(TrimWaveform old) {
    super.didUpdateWidget(old);

    if (widget.playhead != old.playhead) {
      _anchorPlayhead = widget.playhead ?? Duration.zero;
      _anchorElapsed = _ticker.isActive ? _lastElapsed : Duration.zero;
      _sweptPlayhead = _anchorPlayhead;
    }

    if (_wantsFrames && !_ticker.isActive) {
      _lastElapsed = Duration.zero;
      _anchorElapsed = Duration.zero;
      _ticker.start();
    } else if (!_wantsFrames && _ticker.isActive) {
      _ticker.stop();
      _sweptPlayhead = widget.playhead ?? Duration.zero;
    }
  }

  Duration _lastElapsed = Duration.zero;

  void _onTick(Duration elapsed) {
    _lastElapsed = elapsed;

    // While there is nothing to sweep, the frames exist only to run the
    // placeholder, so the phase is all that needs to change.
    if (!widget.isPlaying) {
      setState(() {});
      return;
    }

    final int since = (elapsed - _anchorElapsed).inMicroseconds;
    final Duration swept =
        _anchorPlayhead +
        Duration(microseconds: (since * widget.speed).round());

    // Never sweep past the end of the selection: the clip stops there, and a
    // playhead that ran on past it would be showing something untrue.
    final Duration capped = swept > widget.end ? widget.end : swept;
    if (capped != _sweptPlayhead) {
      setState(() => _sweptPlayhead = capped);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  double get _totalMs => widget.total.inMilliseconds.toDouble();

  double _fractionOf(Duration position) {
    if (_totalMs <= 0) {
      return 0;
    }
    return (position.inMilliseconds / _totalMs).clamp(0.0, 1.0);
  }

  /// Where [position] falls, in pixels from the widget's left edge.
  double _xOf(Duration position) =>
      TrimWaveform.edgeInset + _fractionOf(position) * _trackWidth;

  Duration _durationAt(double dx) {
    if (_trackWidth <= 0 || _totalMs <= 0) {
      return Duration.zero;
    }
    final double fraction = (dx / _trackWidth).clamp(0.0, 1.0);
    return Duration(milliseconds: (fraction * _totalMs).round());
  }

  void _onDragStart(DragStartDetails details) {
    if (_totalMs <= 0) {
      return;
    }
    final double x = details.localPosition.dx - TrimWaveform.edgeInset;
    final double startX = _fractionOf(widget.start) * _trackWidth;
    final double endX = _fractionOf(widget.end) * _trackWidth;

    final double toStart = (x - startX).abs();
    final double toEnd = (x - endX).abs();

    // Ties go to the handle the drag moves away from, so a grab on top of a
    // collapsed selection can still be pulled open in either direction.
    if (toStart > TrimWaveform._grabRadius &&
        toEnd > TrimWaveform._grabRadius) {
      _dragging = null;
      return;
    }
    setState(() => _dragging = toStart <= toEnd ? _Handle.start : _Handle.end);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final _Handle? handle = _dragging;
    if (handle == null) {
      return;
    }

    final Duration at = _durationAt(
      details.localPosition.dx - TrimWaveform.edgeInset,
    );
    const Duration gap = TrimWaveform.minimumSelection;

    switch (handle) {
      case _Handle.start:
        final Duration limit = widget.end - gap;
        widget.onChanged(at > limit ? limit : at, widget.end);
      case _Handle.end:
        final Duration limit = widget.start + gap;
        widget.onChanged(widget.start, at < limit ? limit : at);
    }
  }

  void _endDrag() {
    if (_dragging != null) {
      setState(() => _dragging = null);
    }
  }

  /// Where a handle lands after one nudge from assistive technology, which
  /// cannot drag. Returned rather than applied, because the same value is also
  /// what the screen reader announces the action will produce.
  Duration _nudged(_Handle handle, {required bool forward}) {
    final Duration step = Duration(
      milliseconds: math.max(500, (_totalMs / 50).round()),
    );
    const Duration gap = TrimWaveform.minimumSelection;

    switch (handle) {
      case _Handle.start:
        final Duration moved = forward
            ? widget.start + step
            : widget.start - step;
        final int limit = math.max(
          0,
          widget.end.inMilliseconds - gap.inMilliseconds,
        );
        return Duration(milliseconds: moved.inMilliseconds.clamp(0, limit));
      case _Handle.end:
        final Duration moved = forward ? widget.end + step : widget.end - step;
        final int floor = math.min(
          widget.start.inMilliseconds + gap.inMilliseconds,
          _totalMs.round(),
        );
        return Duration(
          milliseconds: moved.inMilliseconds.clamp(floor, _totalMs.round()),
        );
    }
  }

  void _nudge(_Handle handle, {required bool forward}) {
    final Duration landed = _nudged(handle, forward: forward);
    switch (handle) {
      case _Handle.start:
        widget.onChanged(landed, widget.end);
      case _Handle.end:
        widget.onChanged(widget.start, landed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color accent = widget.accent ?? colors.primary;

    return Semantics(
      container: true,
      label: 'Trim selection',
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          _trackWidth = math.max(
            0,
            constraints.maxWidth - TrimWaveform.edgeInset * 2,
          );

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: (_) => _endDrag(),
            onHorizontalDragCancel: _endDrag,
            child: Stack(
              children: <Widget>[
                CustomPaint(
                  size: Size(constraints.maxWidth, constraints.maxHeight),
                  painter: _WaveformPainter(
                    inset: TrimWaveform.edgeInset,
                    peaks: widget.peaks,
                    startFraction: _fractionOf(widget.start),
                    endFraction: _fractionOf(widget.end),
                    playheadFraction: widget.isPlaying
                        ? _fractionOf(_sweptPlayhead)
                        : null,
                    isLoading: widget.isLoading,
                    phase: _lastElapsed.inMilliseconds / 1000,
                    accent: accent,
                    // The playhead has to stand out from the tinted bed it
                    // travels over, which is light in one theme and dark in
                    // the other, so it cannot simply be white.
                    playheadColor: theme.brightness == Brightness.dark
                        ? Colors.white
                        : Color.lerp(accent, Colors.black, 0.5)!,
                    muted: colors.onSurfaceVariant,
                    dragging: _dragging != null,
                  ),
                ),
                // Affordances so a screen reader can move the handles that a
                // sighted user drags. They sit over the handles at a real
                // size: a zero-sized Semantics produces no node at all, so an
                // off-screen one would have been accessibility on paper only.
                for (final _Handle handle in _Handle.values)
                  Positioned(
                    left:
                        _xOf(
                          handle == _Handle.start ? widget.start : widget.end,
                        ) -
                        _semanticsWidth / 2,
                    top: 0,
                    bottom: 0,
                    width: _semanticsWidth,
                    child: _HandleSemantics(
                      label: handle == _Handle.start
                          ? 'Selection start'
                          : 'Selection end',
                      value: handle == _Handle.start
                          ? widget.start
                          : widget.end,
                      increasedValue: _nudged(handle, forward: true),
                      decreasedValue: _nudged(handle, forward: false),
                      onIncrease: () => _nudge(handle, forward: true),
                      onDecrease: () => _nudge(handle, forward: false),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HandleSemantics extends StatelessWidget {
  const _HandleSemantics({
    required this.label,
    required this.value,
    required this.increasedValue,
    required this.decreasedValue,
    required this.onIncrease,
    required this.onDecrease,
  });

  final String label;
  final Duration value;
  final Duration increasedValue;
  final Duration decreasedValue;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    // Flutter requires the before-and-after values alongside the actions:
    // without them a screen reader announces a move it cannot describe, and
    // the framework asserts rather than letting that ship.
    return Semantics(
      slider: true,
      label: label,
      value: _spoken(value),
      increasedValue: _spoken(increasedValue),
      decreasedValue: _spoken(decreasedValue),
      onIncrease: onIncrease,
      onDecrease: onDecrease,
      // Sized, not shrunk, so the node has a rect to be found and focused at.
      // It stays transparent to pointers, leaving the drag to the waveform.
      child: const SizedBox.expand(),
    );
  }

  static String _spoken(Duration value) {
    final int minutes = value.inMinutes;
    final int seconds = value.inSeconds % 60;
    return '$minutes minutes $seconds seconds';
  }
}

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.inset,
    required this.peaks,
    required this.startFraction,
    required this.endFraction,
    required this.playheadFraction,
    required this.isLoading,
    required this.phase,
    required this.accent,
    required this.playheadColor,
    required this.muted,
    required this.dragging,
  });

  final double inset;
  final List<double> peaks;
  final double startFraction;
  final double endFraction;
  final double? playheadFraction;
  final bool isLoading;

  /// Seconds since the ticker started, which is what drives the placeholder.
  final double phase;

  final Color accent;
  final Color playheadColor;
  final Color muted;
  final bool dragging;

  @override
  void paint(Canvas canvas, Size size) {
    final double centre = size.height / 2;
    final double trackWidth = math.max(0, size.width - inset * 2);
    final double startX = inset + startFraction * trackWidth;
    final double endX = inset + endFraction * trackWidth;

    // The selected stretch gets a tinted bed, so the choice is legible even
    // where the track is near silent and the bars themselves are hairlines.
    canvas.drawRect(
      Rect.fromLTRB(startX, 0, endX, size.height),
      Paint()..color = accent.withValues(alpha: 0.1),
    );

    final double? headX = playheadFraction == null
        ? null
        : inset + playheadFraction! * trackWidth;

    // What has already been heard, filled in behind the playhead.
    if (headX != null && headX > startX) {
      canvas.drawRect(
        Rect.fromLTRB(startX, 0, headX, size.height),
        Paint()..color = accent.withValues(alpha: 0.16),
      );
    }

    if (isLoading) {
      _paintPlaceholder(canvas, centre, trackWidth);
    } else if (peaks.isNotEmpty) {
      _paintBars(canvas, centre, trackWidth, startX, endX, headX);
    } else {
      // Decoded and came back with nothing: a centre line, because inventing
      // a shape here would point the user at a place the sound is not.
      canvas.drawLine(
        Offset(inset, centre),
        Offset(size.width - inset, centre),
        Paint()
          ..color = muted.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
    }

    _paintHandle(canvas, size, startX);
    _paintHandle(canvas, size, endX);

    if (headX != null) {
      _paintPlayhead(canvas, size, headX);
    }
  }

  void _paintBars(
    Canvas canvas,
    double centre,
    double trackWidth,
    double startX,
    double endX,
    double? headX,
  ) {
    // Bars are sized for the screen, not for the data. The decode keeps more
    // resolution than a phone can show, so drawing one bar per value gives
    // hairlines packed edge to edge — a grey smear rather than a waveform.
    final int bars = math.max(
      1,
      math.min(peaks.length, trackWidth ~/ _barSlot),
    );
    final double step = trackWidth / bars;
    final double barWidth = math.max(1.5, step * 0.6);
    final double usable = centre - 4;

    // Heard already is the solid colour; still to come is faded. The other
    // way round reads as the preview undoing itself as it plays.
    final Paint played = Paint()..color = accent;
    final Paint ahead = Paint()..color = accent.withValues(alpha: 0.4);
    final Paint outside = Paint()..color = muted.withValues(alpha: 0.38);
    final Color glowColor = Color.lerp(accent, playheadColor, 0.55)!;

    // Bars keep their true heights while playing; the life comes from a band
    // of light travelling with the sound. Scaling bars near the playhead would
    // look livelier and would also be a lie — every height here means how loud
    // that moment is, and the user is aiming at it.
    const double glowSpan = 26;

    for (int i = 0; i < bars; i++) {
      final double x = inset + i * step + step / 2;
      // A floor of one pixel: a silent passage is part of the track's shape,
      // and a gap in the drawing reads as missing data instead of as quiet.
      final double half = math.max(1, _heightAt(i, bars) * usable);
      final bool selected = x >= startX && x <= endX;

      // With nothing playing there is no "already heard", so the whole
      // selection stays solid rather than half of it looking spent.
      Paint paint = !selected
          ? outside
          : (headX == null || x <= headX ? played : ahead);

      if (selected && headX != null) {
        final double nearness = 1 - ((x - headX).abs() / glowSpan);
        if (nearness > 0) {
          paint = Paint()
            ..color = Color.lerp(paint.color, glowColor, nearness * 0.85)!;
        }
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - barWidth / 2,
            centre - half,
            x + barWidth / 2,
            centre + half,
          ),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  /// The waiting state: a wave running left to right while the track decodes.
  ///
  /// Openly a placeholder — an even wave no recording produces — so nobody can
  /// mistake it for the shape of their audio while it is still being read.
  void _paintPlaceholder(Canvas canvas, double centre, double trackWidth) {
    final int bars = math.max(1, trackWidth ~/ _barSlot);
    final double step = trackWidth / bars;
    final double barWidth = math.max(1.5, step * 0.6);
    final double usable = centre - 4;

    for (int i = 0; i < bars; i++) {
      // Two waves at different rates, so the run never looks like it is
      // repeating on a short loop.
      final double t = i / bars;
      final double wave =
          0.5 +
          0.32 * math.sin(phase * 3.4 - t * 9) +
          0.18 * math.sin(phase * 1.7 - t * 4);

      // A brighter crest travels along, which is what turns a row of bars
      // into something that reads as working rather than as stalled.
      final double crest = (1 - ((t - (phase * 0.42) % 1.4 + 0.2).abs() * 3))
          .clamp(0.0, 1.0);

      final double x = inset + i * step + step / 2;
      final double half = math.max(1, wave.clamp(0.12, 1.0) * usable * 0.7);

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            x - barWidth / 2,
            centre - half,
            x + barWidth / 2,
            centre + half,
          ),
          Radius.circular(barWidth / 2),
        ),
        Paint()
          ..color = Color.lerp(
            muted.withValues(alpha: 0.22),
            accent.withValues(alpha: 0.7),
            crest,
          )!,
      );
    }
  }

  /// The height of drawn bar [i] of [bars], folding together however many
  /// decoded values it stands for.
  ///
  /// The loudest of the group wins: these are already per-slice loudnesses, so
  /// averaging them a second time would sand the track flat again.
  double _heightAt(int i, int bars) {
    final int from = peaks.length * i ~/ bars;
    final int to = math.max(from + 1, peaks.length * (i + 1) ~/ bars);

    double tallest = 0;
    for (int p = from; p < to && p < peaks.length; p++) {
      if (peaks[p] > tallest) {
        tallest = peaks[p];
      }
    }
    return tallest;
  }

  /// The line that travels with the sound.
  void _paintPlayhead(Canvas canvas, Size size, double x) {
    final Paint paint = Paint()..color = playheadColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - 1, 4, x + 1, size.height - 4),
        const Radius.circular(1),
      ),
      paint,
    );
    canvas.drawCircle(Offset(x, 4), 3, paint);
  }

  void _paintHandle(Canvas canvas, Size size, double x) {
    const double width = 3;
    final Paint paint = Paint()..color = accent;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(x - width / 2, 0, x + width / 2, size.height),
        const Radius.circular(width / 2),
      ),
      paint,
    );

    // Caps at both ends, which is what makes the line read as a grabbable
    // handle rather than as a marker drawn on the track.
    final double radius = dragging ? 6 : 5;
    canvas.drawCircle(Offset(x, radius), radius, paint);
    canvas.drawCircle(Offset(x, size.height - radius), radius, paint);
  }

  @override
  bool shouldRepaint(_WaveformPainter old) {
    return old.inset != inset ||
        old.phase != phase ||
        old.isLoading != isLoading ||
        old.playheadFraction != playheadFraction ||
        old.playheadColor != playheadColor ||
        old.startFraction != startFraction ||
        old.endFraction != endFraction ||
        old.dragging != dragging ||
        old.accent != accent ||
        !identical(old.peaks, peaks);
  }
}

/// The space the waveform occupies.
///
/// No outline and no fill of its own: the bars already give the block a clear
/// shape, so a border and a dark panel behind them only added edges to read.
/// It sits straight on whatever the page's background is.
class TrimWaveformFrame extends StatelessWidget {
  const TrimWaveformFrame({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimens.spaceSm),
      child: SizedBox(height: 108 - AppDimens.spaceSm * 2, child: child),
    );
  }
}
