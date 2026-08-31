import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/presentation/widgets/mix_track_list.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

MediaInfo clip(String name) => MediaInfo(
  path: '/in/$name.mp3',
  name: '$name.mp3',
  sizeInBytes: 1024,
  extension: 'mp3',
  hasAudio: true,
  hasVideo: false,
  duration: const Duration(minutes: 2),
);

void main() {
  late List<(int, int)> reorders;

  setUp(() => reorders = <(int, int)>[]);

  /// Renders the timeline's own configuration of the list.
  Future<void> pumpList(WidgetTester tester, {int count = 2}) async {
    final List<MediaInfo> sources = <MediaInfo>[
      for (int i = 0; i < count; i++) clip('clip$i'),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: ListView(
            children: <Widget>[
              MixTrackList(
                sources: sources,
                volumes: List<double>.filled(count, 1),
                starts: List<Duration>.filled(count, Duration.zero),
                showsPositions: true,
                trimRanges: <(Duration, Duration)>[
                  for (int i = 0; i < count; i++)
                    (Duration.zero, const Duration(minutes: 2)),
                ],
                onTrimChanged: (_, _, _) {},
                onVolumeChanged: null,
                onRemove: (_) {},
                onReorder: (int oldIndex, int newIndex) =>
                    reorders.add((oldIndex, newIndex)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Presses and holds [finder], drags it by [offset], and lets go.
  Future<void> longPressDrag(
    WidgetTester tester,
    Finder finder,
    Offset offset,
  ) async {
    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(finder),
    );
    await tester.pump(kLongPressTimeout + kPressTimeout);
    await gesture.moveBy(offset);
    await tester.pumpAndSettle();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  group('moving a clip', () {
    testWidgets('holding the card and dragging reorders it', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);

      // Grabbing the small handle is fiddly on a phone; the card itself has
      // to be what moves the clip.
      await longPressDrag(
        tester,
        find.text('clip1.mp3'),
        const Offset(0, -150),
      );

      expect(reorders, isNotEmpty);
      expect(reorders.first.$1, 1);
    });

    testWidgets('the handle picks a clip up without the wait', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);

      final TestGesture gesture = await tester.startGesture(
        tester.getCenter(find.byIcon(Icons.drag_handle_rounded).last),
      );
      await gesture.moveBy(const Offset(0, -150));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(reorders, isNotEmpty);
    });

    testWidgets('dragging the selection slider does not move the clip', (
      WidgetTester tester,
    ) async {
      await pumpList(tester);

      // The slider sits inside the row, so a drag there must adjust the
      // selection rather than picking the clip up.
      await longPressDrag(
        tester,
        find.byType(RangeSlider).last,
        const Offset(0, -150),
      );

      expect(reorders, isEmpty);
    });

    testWidgets('clips are numbered by their place in the list', (
      WidgetTester tester,
    ) async {
      await pumpList(tester, count: 3);

      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });
  });
}
