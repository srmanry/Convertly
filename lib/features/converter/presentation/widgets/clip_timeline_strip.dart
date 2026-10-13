import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'timeline_scrollbar.dart';

/// One clip's place on the timeline.
class TimelineClip {
  const TimelineClip({
    required this.label,
    required this.start,
    required this.length,
    this.name,
  });

  final String label;
  final String? name;
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
class ClipTimelineStrip extends StatefulWidget {
  const ClipTimelineStrip({
    required this.clips,
    required this.total,
    super.key,
    this.playhead,
    this.onReorder,
  });

  /// Height of the waveform overview.
  static const double stripHeight = 72;

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

  /// Called when a block is dragged to a new place in the run.
  ///
  /// Indices follow `onReorderItem`: [newIndex] is where the clip lands once
  /// it has been lifted out. Null leaves the blocks fixed.
  final void Function(int oldIndex, int newIndex)? onReorder;

  @override
  State<ClipTimelineStrip> createState() => _ClipTimelineStripState();
}

class _ClipTimelineStripState extends State<ClipTimelineStrip>
    with SingleTickerProviderStateMixin {
  /// One sweep of the moving waveform in the clip being played.
  ///
  /// Fast enough to read as sound, slow enough not to flicker beside the
  /// playhead crossing the same block.
  static const Duration _sweep = Duration(milliseconds: 900);

  late final AnimationController _bars = AnimationController(
    vsync: this,
    duration: _sweep,
  );

  /// Block being dragged, or null when nothing is being moved.
  int? _dragging;

  /// Where the finger is along the strip, in its own pixels.
  double _dragOffset = 0;

  final ScrollController _scroll = ScrollController();
  Timer? _edgeScroll;
  double _viewportWidth = 0;
  double _pointerX = 0;

  double get _scrollOffset =>
      _scroll.hasClients ? _scroll.positions.last.pixels : 0;

  void _beginDrag(double contentX) {
    final int? index = _blockAt(contentX);
    if (index == null) return;
    setState(() {
      _dragging = index;
      _dragOffset = contentX;
    });
    _edgeScroll?.cancel();
    _edgeScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_dragging == null || _scroll.positions.length != 1) return;
      const double edge = 32;
      final double direction = _pointerX < edge
          ? -((edge - _pointerX) / edge).clamp(0.0, 1.0)
          : _pointerX > _viewportWidth - edge
          ? ((_pointerX - (_viewportWidth - edge)) / edge).clamp(0.0, 1.0)
          : 0;
      if (direction == 0) return;
      final double next = (_scroll.offset + direction * 5).clamp(
        0.0,
        _scroll.position.maxScrollExtent,
      );
      if (next == _scroll.offset) return;
      _scroll.jumpTo(next);
      setState(() => _dragOffset = _pointerX + next);
    });
  }

  void _moveDrag(double viewportX) {
    if (_dragging == null) return;
    setState(() {
      _pointerX = viewportX;
      _dragOffset = viewportX + _scrollOffset;
    });
  }

  /// The run as it would be if the drag ended now.
  ///
  /// Clips play back to back, so moving one re-times every clip after it.
  /// Laying the preview out from the moved order is what makes the other
  /// blocks step aside while the finger is still down.
  (List<TimelineClip> clips, int movedTo) get _previewOrder {
    final List<TimelineClip> source = widget.clips;
    final int? from = _dragging;
    if (from == null || source.isEmpty) {
      return (source, -1);
    }

    final int to = _targetIndex(from);
    final List<TimelineClip> reordered = List<TimelineClip>.of(source);
    final TimelineClip moved = reordered.removeAt(from);
    reordered.insert(to.clamp(0, reordered.length), moved);

    // Re-time the run: each clip starts where the one before it ended.
    final List<TimelineClip> timed = <TimelineClip>[];
    Duration cursor = Duration.zero;
    for (final TimelineClip clip in reordered) {
      timed.add(
        TimelineClip(
          label: clip.label,
          name: clip.name,
          start: cursor,
          length: clip.length,
        ),
      );
      cursor += clip.length;
    }
    return (timed, to.clamp(0, timed.length - 1));
  }

  /// Left edge and width of every block as drawn, preview order included.
  ///
  /// Written during layout because the widths are not a plain proportion any
  /// more: a short clip is widened to stay readable, which the playhead has
  /// to measure against.
  List<double> _lefts = <double>[];
  List<double> _widths = <double>[];

  /// The same, for the run as it stands before any drag.
  ///
  /// Hit testing has to use this one. Measuring against the drawn layout read
  /// the slot the block had already been previewed into, so every drag looked
  /// like it had landed where it started and nothing ever moved.
  List<double> _baseLefts = <double>[];
  List<double> _baseWidths = <double>[];

  /// Narrowest a block may be drawn.
  ///
  /// Keeps short clips visible and large enough to grab when reordering.
  static const double _readableWidth = 46;

  /// Lays the run out, widening whatever would be too thin to see.
  ///
  /// When every clip is already wide enough the blocks keep their exact share
  /// of the width and the strip does not scroll, which is how it has always
  /// looked for an even run.
  ///
  /// Silence between clips keeps its own share of the width. This tool plays
  /// clips back to back, but the strip can be handed a run with holes in it
  /// and must not quietly close them up.
  (List<double> lefts, List<double> widths, double content) _layout(
    List<TimelineClip> laid,
    double viewport,
    int totalMs,
  ) {
    double natural(Duration span) => viewport * span.inMilliseconds / totalMs;

    final List<double> naturalWidths = <double>[
      for (final TimelineClip clip in laid) natural(clip.length),
    ];
    final bool allReadable = naturalWidths.every(
      (double w) => w >= _readableWidth,
    );
    final List<double> widths = allReadable
        ? naturalWidths
        : <double>[
            for (final double w in naturalWidths) math.max(_readableWidth, w),
          ];

    final List<double> lefts = <double>[];
    double cursor = 0;
    Duration played = Duration.zero;
    for (int index = 0; index < laid.length; index++) {
      cursor += natural(laid[index].start - played).clamp(0, viewport);
      lefts.add(cursor);
      cursor += widths[index];
      played = laid[index].start + laid[index].length;
    }

    // Trailing silence counts too, or a run that ends early would stretch to
    // fill the strip and read as longer than it is.
    final double tail = natural(widget.total - played).clamp(0, viewport);
    return (lefts, widths, math.max(cursor + tail, viewport));
  }

  /// Which slot the finger is currently over.
  int _targetIndex(int from) => _blockAt(_dragOffset) ?? from;

  /// Block under [dx] in the undragged run, measured in the strip's pixels.
  int? _blockAt(double dx) {
    for (int index = 0; index < _baseWidths.length; index++) {
      if (dx < _baseLefts[index] + _baseWidths[index]) {
        return index;
      }
    }
    return _baseWidths.isEmpty ? null : _baseWidths.length - 1;
  }

  /// Which clip the playhead is inside, or null when nothing is playing.
  int? get _activeIndex {
    final Duration? position = widget.playhead;
    if (position == null) {
      return null;
    }
    for (int index = 0; index < widget.clips.length; index++) {
      final TimelineClip clip = widget.clips[index];
      if (position >= clip.start && position < clip.start + clip.length) {
        return index;
      }
    }
    return null;
  }

  void _syncToPlayback() {
    // Only while the playhead is actually inside a clip. Sitting in a gap, or
    // run off the end, there is nothing to animate and no reason to keep the
    // screen redrawing.
    final bool playing = _activeIndex != null;
    if (playing == _bars.isAnimating) {
      return;
    }
    if (playing) {
      _bars.repeat();
    } else {
      // Stopped rather than left running: a strip nobody is listening to
      // should not keep the screen redrawing.
      _bars
        ..stop()
        ..value = 0;
    }
  }

  @override
  void didUpdateWidget(ClipTimelineStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncToPlayback();
  }

  @override
  void dispose() {
    _edgeScroll?.cancel();
    _scroll.dispose();
    _bars.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _syncToPlayback();
    final List<TimelineClip> clips = widget.clips;
    final Duration total = widget.total;
    final Duration? playhead = widget.playhead;
    final ThemeData theme = Theme.of(context);
    final int totalMs = total.inMilliseconds;

    if (clips.isEmpty || totalMs <= 0) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double viewport = constraints.maxWidth;
            _viewportWidth = viewport;

            final (List<TimelineClip> laid, int movedTo) = _previewOrder;
            final bool dragging = _dragging != null;

            final (List<double> lefts, List<double> widths, double content) =
                _layout(laid, viewport, totalMs);
            _lefts = lefts;
            _widths = widths;

            // Measured again from the untouched run, which is what a finger
            // is pointing at while the drawn blocks are stepping aside.
            final (List<double> baseLefts, List<double> baseWidths, _) =
                _layout(widget.clips, viewport, totalMs);
            _baseLefts = baseLefts;
            _baseWidths = baseWidths;

            final Widget stack = SizedBox(
              width: content,
              child: Stack(
                children: <Widget>[
                  for (int index = 0; index < laid.length; index++)
                    _block(index, laid, lifted: dragging && index == movedTo),
                  // Hidden while dragging: the marker belongs to playback,
                  // and the run it points into is being rearranged.
                  if (!dragging)
                    if (playhead case final Duration position)
                      _playhead(theme, laid, position),
                ],
              ),
            );

            final Widget scrollView = SingleChildScrollView(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: stack,
            );
            final Widget waveform = widget.onReorder == null
                ? scrollView
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    // Drag clips directly to reorder; the separate rail scrolls.
                    onHorizontalDragDown: (DragDownDetails details) {
                      _pointerX = details.localPosition.dx;
                    },
                    onHorizontalDragStart: (_) {
                      _beginDrag(_pointerX + _scrollOffset);
                    },
                    onHorizontalDragUpdate: (DragUpdateDetails details) =>
                        _moveDrag(details.localPosition.dx),
                    onHorizontalDragEnd: (_) => _finishDrag(),
                    onHorizontalDragCancel: _cancelDrag,
                    onLongPressStart: (LongPressStartDetails details) {
                      _pointerX = details.localPosition.dx;
                      _beginDrag(_pointerX + _scrollOffset);
                    },
                    onLongPressMoveUpdate:
                        (LongPressMoveUpdateDetails details) =>
                            _moveDrag(details.localPosition.dx),
                    onLongPressEnd: (_) => _finishDrag(),
                    onLongPressCancel: _cancelDrag,
                    child: scrollView,
                  );
            return Column(
              children: <Widget>[
                SizedBox(
                  height: ClipTimelineStrip.stripHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: waveform,
                  ),
                ),
                TimelineScrollbar(
                  controller: _scroll,
                  viewportExtent: viewport,
                  contentExtent: content,
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _finishDrag() {
    _edgeScroll?.cancel();
    final int? from = _dragging;
    if (from == null) {
      return;
    }
    final int to = _targetIndex(from);
    setState(() => _dragging = null);
    if (to != from) {
      widget.onReorder?.call(from, to);
    }
  }

  void _cancelDrag() {
    _edgeScroll?.cancel();
    if (_dragging != null) {
      setState(() => _dragging = null);
    }
  }

  Widget _block(int index, List<TimelineClip> laid, {bool lifted = false}) {
    final TimelineClip clip = laid[index];
    // Cycled from the same accents the mixer gives each of its tracks, so a
    // clip reads as its own voice here too, rather than just alternating
    // between two theme colours.
    final Color accent =
        AppColors.mixTrackAccents[index % AppColors.mixTrackAccents.length];
    final Color color = Theme.of(context).brightness == Brightness.dark
        ? accent
        : Color.alphaBlend(Colors.black.withValues(alpha: 0.45), accent);
    final double blockWidth = _widths[index];

    return Positioned(
      left: _lefts[index],
      top: 0,
      bottom: 0,
      width: blockWidth,
      child: DecoratedBox(
        key: ClipTimelineStrip.blockKey(index),
        decoration: const BoxDecoration(),
        child: Semantics(
          label: clip.name ?? clip.label,
          child: Column(
            children: <Widget>[
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: _ClipWaveform(
                    color: color,
                    seed: Object.hash(clip.label, clip.name),
                    beat: index == _activeIndex ? _bars : null,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              Text(
                clip.label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: lifted ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  /// Where playback has reached, placed against the laid-out blocks rather
  /// than against the clock: a widened clip no longer occupies its share of
  /// the width, so the two no longer agree.
  Widget _playhead(ThemeData theme, List<TimelineClip> laid, Duration at) {
    for (int index = 0; index < laid.length; index++) {
      final TimelineClip clip = laid[index];
      final int lengthMs = clip.length.inMilliseconds;
      if (lengthMs <= 0 || at < clip.start || at >= clip.start + clip.length) {
        continue;
      }
      final double into =
          (at - clip.start).inMilliseconds / lengthMs * _widths[index];
      return Positioned(
        left: _lefts[index] + into,
        top: 0,
        bottom: 0,
        width: 2,
        child: ColoredBox(color: theme.colorScheme.onSurface),
      );
    }
    return const SizedBox.shrink();
  }
}

/// One clip's waveform, still unless [beat] is given.
///
/// Behind a boundary of its own so the clip that is playing repaints alone,
/// rather than dragging the rest of the strip along with it every frame.
class _ClipWaveform extends StatelessWidget {
  const _ClipWaveform({
    required this.color,
    required this.seed,
    required this.beat,
    this.child,
  });

  final Color color;
  final int seed;
  final Animation<double>? beat;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final Animation<double>? beat = this.beat;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _WaveformTexturePainter(
          color: color,
          seed: seed,
          // Null while still: the painter then draws the fixed texture and
          // never repaints.
          beat: beat,
          lit: beat != null,
        ),
        child: child,
      ),
    );
  }
}

class _WaveformTexturePainter extends CustomPainter {
  _WaveformTexturePainter({
    required this.color,
    required this.seed,
    required this.lit,
    this.beat,
  }) : super(repaint: beat);

  static const double _barWidth = 2;
  static const double _gap = 3;

  final Color color;
  final int seed;

  /// Drives the movement; null leaves the texture still.
  final Animation<double>? beat;

  /// Brighter while playing, so the clip stands out even at a glance that
  /// catches the bars mid-stride.
  final bool lit;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) {
      return;
    }

    final double phase = (beat?.value ?? 0) * 2 * math.pi;
    final math.Random random = math.Random(seed);
    final Paint paint = Paint()
      ..color = color.withValues(alpha: lit ? 0.95 : 0.65);
    final double middle = size.height / 2;

    int bar = 0;
    for (double x = 2; x < size.width - _barWidth; x += _barWidth + _gap) {
      final double resting = 0.2 + random.nextDouble() * 0.65;
      // Each bar is a step further along the wave than the one before it, so
      // the movement travels across the clip instead of every bar pumping
      // together.
      final double swing = beat == null
          ? 0
          : 0.22 * math.sin(phase + bar * 0.6);
      final double reach = (resting + swing).clamp(0.12, 0.95);
      final double barHeight = (size.height * reach).clamp(2.0, size.height);
      final RRect rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, middle - barHeight / 2, _barWidth, barHeight),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(rect, paint);
      bar++;
    }
  }

  @override
  bool shouldRepaint(_WaveformTexturePainter old) =>
      old.color != color ||
      old.seed != seed ||
      old.lit != lit ||
      old.beat != beat;
}
