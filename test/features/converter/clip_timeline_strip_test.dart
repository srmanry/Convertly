import 'package:convertly/features/converter/presentation/widgets/timeline_scrollbar.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/presentation/widgets/clip_timeline_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Renders the strip at a known width so block positions can be measured
  /// against the timeline they represent.
  Future<void> pumpStrip(
    WidgetTester tester, {
    required List<TimelineClip> clips,
    required Duration total,
    Duration? playhead,
    void Function(int oldIndex, int newIndex)? onReorder,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 300,
              child: ClipTimelineStrip(
                clips: clips,
                total: total,
                playhead: playhead,
                onReorder: onReorder,
              ),
            ),
          ),
        ),
      ),
    );
    // Not pumpAndSettle: the clip being played animates for as long as it
    // plays, so there is nothing to settle to.
    await tester.pump();
  }

  /// Horizontal span of the block drawn for the clip at [index].
  ///
  /// Found by key rather than by its label, since a narrow block carries no
  /// text to search for.
  (double left, double width) blockSpan(WidgetTester tester, int index) {
    final Rect rect = tester.getRect(
      find.byKey(ClipTimelineStrip.blockKey(index)),
    );
    return (rect.left, rect.width);
  }

  const List<TimelineClip> sequence = <TimelineClip>[
    TimelineClip(
      label: '1',
      start: Duration.zero,
      length: Duration(seconds: 40),
    ),
    TimelineClip(
      label: '2',
      start: Duration(seconds: 40),
      length: Duration(seconds: 20),
    ),
  ];

  group('ClipTimelineStrip', () {
    testWidgets('a short clip stays readable, and the strip scrolls for it', (
      WidgetTester tester,
    ) async {
      // The reported bug: a short clip beside long ones was squeezed into a
      // sliver at the edge of the strip, too narrow to read or to grab.
      const List<TimelineClip> lopsided = <TimelineClip>[
        TimelineClip(
          label: '1',
          start: Duration.zero,
          length: Duration(seconds: 2),
        ),
        TimelineClip(
          label: '2',
          start: Duration(seconds: 2),
          length: Duration(seconds: 358),
        ),
      ];

      await pumpStrip(
        tester,
        clips: lopsided,
        total: const Duration(seconds: 360),
      );

      // Two seconds of six minutes would be under two pixels of a 300px
      // strip. It is widened instead, and the run grows past the screen.
      final (double left, double width) = blockSpan(tester, 0);
      final (double nextLeft, _) = blockSpan(tester, 1);
      expect(width, greaterThan(40));
      // Still first, and still touching the clip that follows it.
      expect(nextLeft, left + width);
      expect(find.byType(Scrollable), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block can be dragged to a new place in the run', (
      WidgetTester tester,
    ) async {
      (int, int)? moved;
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
        onReorder: (int from, int to) => moved = (from, to),
      );

      // The second clip runs 40s–60s of a 60s strip 300px wide, so it sits
      // in the right third; the first fills the left two thirds.
      final Offset second = tester.getCenter(
        find.byKey(ClipTimelineStrip.blockKey(1)),
      );
      final Offset first = tester.getCenter(
        find.byKey(ClipTimelineStrip.blockKey(0)),
      );

      // Long press to lift, since an ordinary drag belongs to the page.
      final TestGesture drag = await tester.startGesture(second);
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(first);
      await tester.pump();
      await drag.up();
      await tester.pump();

      expect(moved, (1, 0));
    });

    testWidgets('a plain horizontal drag reorders without scrolling', (
      WidgetTester tester,
    ) async {
      // Navigation is available only through the explicit scrollbar.
      (int, int)? moved;
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
        onReorder: (int from, int to) => moved = (from, to),
      );

      await tester.drag(
        find.byKey(ClipTimelineStrip.blockKey(1)),
        const Offset(-150, 0),
      );
      await tester.pump();

      expect(moved, (1, 0));
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        0,
      );
    });

    testWidgets('dragging near the edge scrolls to offscreen clips', (
      tester,
    ) async {
      (int, int)? moved;
      final many = List<TimelineClip>.generate(
        20,
        (i) => TimelineClip(
          label: '${i + 1}',
          start: Duration(seconds: i * 5),
          length: const Duration(seconds: 5),
        ),
      );
      await pumpStrip(
        tester,
        clips: many,
        total: const Duration(seconds: 100),
        onReorder: (from, to) => moved = (from, to),
      );
      final Rect first = tester.getRect(
        find.byKey(ClipTimelineStrip.blockKey(0)),
      );
      final drag = await tester.startGesture(first.center);
      await tester.pump(const Duration(milliseconds: 600));
      await drag.moveTo(Offset(first.left + 297, first.center.dy));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1));
      final ScrollableState scrolling = tester.state(find.byType(Scrollable));
      expect(scrolling.position.pixels, greaterThan(100));
      await drag.up();
      await tester.pumpAndSettle();
      expect(moved?.$1, 0);
      expect(moved?.$2, greaterThan(6));
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'only the scrollbar navigates overflow without changing clip order',
      (tester) async {
        (int, int)? moved;
        final many = List<TimelineClip>.generate(
          20,
          (i) => TimelineClip(
            label: '${i + 1}',
            start: Duration(seconds: i * 5),
            length: const Duration(seconds: 5),
          ),
        );
        await pumpStrip(
          tester,
          clips: many,
          total: const Duration(seconds: 100),
          onReorder: (from, to) => moved = (from, to),
        );
        final ScrollableState scroll = tester.state(find.byType(Scrollable));
        await tester.drag(
          find.byKey(ClipTimelineStrip.blockKey(1)),
          const Offset(-100, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, 0);
        expect(moved, (1, 0));
        moved = null;

        await tester.drag(
          find.byKey(TimelineScrollbar.thumbKey),
          const Offset(70, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(100));
        expect(moved, isNull);
        final double before = scroll.position.pixels;
        await tester.drag(
          find.byKey(TimelineScrollbar.thumbKey),
          const Offset(40, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, greaterThan(before));
        await tester.drag(
          find.byKey(TimelineScrollbar.thumbKey),
          const Offset(-40, 0),
        );
        await tester.pumpAndSettle();
        expect(scroll.position.pixels, lessThanOrEqualTo(before + 1));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a vertical drag scrolls the page without reordering', (
      tester,
    ) async {
      (int, int)? moved;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                const SizedBox(height: 100),
                ClipTimelineStrip(
                  clips: sequence,
                  total: const Duration(seconds: 60),
                  onReorder: (from, to) => moved = (from, to),
                ),
                const SizedBox(height: 1000),
              ],
            ),
          ),
        ),
      );
      await tester.drag(
        find.byKey(ClipTimelineStrip.blockKey(1)),
        const Offset(0, -80),
      );
      await tester.pumpAndSettle();
      expect(moved, isNull);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('only the clip being played moves', (
      WidgetTester tester,
    ) async {
      // Still while nothing is playing: a strip that animates on its own
      // says a clip is sounding when none is.
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
      );
      expect(tester.hasRunningAnimations, isFalse);

      // Inside the second clip, so that one comes alive.
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
        playhead: const Duration(seconds: 45),
      );
      expect(tester.hasRunningAnimations, isTrue);

      // Run off the end of the last clip: nothing is sounding any more.
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
        playhead: const Duration(seconds: 59, milliseconds: 999),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('draws one block per clip', (WidgetTester tester) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
      );

      expect(find.byKey(ClipTimelineStrip.blockKey(0)), findsOneWidget);
      expect(find.byKey(ClipTimelineStrip.blockKey(1)), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('block width follows the clip length', (
      WidgetTester tester,
    ) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
      );

      final (double, double) first = blockSpan(tester, 0);
      final (double, double) second = blockSpan(tester, 1);

      // 40s of a 60s track is twice the width of the 20s that follows it.
      expect(second.$2 / first.$2, closeTo(0.5, 0.05));
    });

    testWidgets('a clip is placed at the time it starts', (
      WidgetTester tester,
    ) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
      );

      final (double, double) strip = blockSpan(tester, 0);
      final (double, double) second = blockSpan(tester, 1);

      // Two thirds of the way along, because it begins at 0:40 of 1:00.
      expect(second.$1 - strip.$1, closeTo(200, 4));
    });

    testWidgets('a gap leaves empty space rather than closing up', (
      WidgetTester tester,
    ) async {
      await pumpStrip(
        tester,
        clips: const <TimelineClip>[
          TimelineClip(
            label: '1',
            start: Duration.zero,
            length: Duration(seconds: 20),
          ),
          TimelineClip(
            label: '2',
            start: Duration(seconds: 60),
            length: Duration(seconds: 20),
          ),
        ],
        total: const Duration(seconds: 80),
      );

      final (double, double) first = blockSpan(tester, 0);
      final (double, double) second = blockSpan(tester, 1);

      // The second clip starts well past where the first one ended, which is
      // the silence between them.
      expect(second.$1, greaterThan(first.$1 + first.$2 + 50));
    });

    testWidgets('endpoint time labels are hidden', (WidgetTester tester) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(minutes: 1, seconds: 10),
      );

      expect(find.text('0:00'), findsNothing);
      expect(find.text('1:10'), findsNothing);
    });

    testWidgets('nothing is drawn without clips', (WidgetTester tester) async {
      await pumpStrip(
        tester,
        clips: const <TimelineClip>[],
        total: const Duration(seconds: 60),
      );

      expect(find.byType(LayoutBuilder), findsNothing);
    });

    testWidgets(
      'a zero-length track draws nothing rather than dividing by it',
      (WidgetTester tester) async {
        await pumpStrip(tester, clips: sequence, total: Duration.zero);

        expect(find.byKey(ClipTimelineStrip.blockKey(0)), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a very short clip stays wide enough to see', (
      WidgetTester tester,
    ) async {
      await pumpStrip(
        tester,
        clips: const <TimelineClip>[
          TimelineClip(
            label: '1',
            start: Duration.zero,
            length: Duration(hours: 1),
          ),
          TimelineClip(
            label: '2',
            start: Duration(hours: 1),
            length: Duration(milliseconds: 200),
          ),
        ],
        total: const Duration(hours: 1, milliseconds: 200),
      );

      expect(tester.takeException(), isNull);
      // Proportionally it would be a fraction of a pixel and vanish.
      expect(
        blockSpan(tester, 1).$2,
        greaterThanOrEqualTo(ClipTimelineStrip.minimumBlockWidth),
      );
    });
  });

  testWidgets('neighbouring blocks touch, leaving no seam', (
    WidgetTester tester,
  ) async {
    await pumpStrip(
      tester,
      clips: sequence,
      total: const Duration(seconds: 60),
    );

    final (double, double) first = blockSpan(tester, 0);
    final (double, double) second = blockSpan(tester, 1);

    // Playback runs straight from one clip into the next, so the picture must
    // not suggest a break between them.
    expect(second.$1, closeTo(first.$1 + first.$2, 0.5));
  });
}
