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
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
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
    testWidgets('draws one block per clip', (WidgetTester tester) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(seconds: 60),
      );

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

    testWidgets('the total length is labelled', (WidgetTester tester) async {
      await pumpStrip(
        tester,
        clips: sequence,
        total: const Duration(minutes: 1, seconds: 10),
      );

      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('1:10'), findsOneWidget);
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
