import 'package:convertly/features/audio_player/domain/entities/player_track.dart';
import 'package:convertly/features/audio_player/presentation/controllers/audio_player_controller.dart';
import 'package:convertly/features/audio_player/presentation/pages/audio_player_page.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

List<PlayerTrack> tracks(int count) => <PlayerTrack>[
  for (int i = 0; i < count; i++)
    PlayerTrack(path: '/music/track_$i.mp3', title: 'Song number $i'),
];

void main() {
  tearDown(Get.reset);

  Future<void> pumpPlayer(
    WidgetTester tester, {
    required int trackCount,
    Size size = const Size(360, 640),
    double textScale = 1,
    int startIndex = 0,
  }) async {
    tester.view.physicalSize = size * tester.view.devicePixelRatio;
    addTearDown(tester.view.reset);

    Get.put<AudioPlayerController>(
      AudioPlayerController(queue: tracks(trackCount), startIndex: startIndex),
    );

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const AudioPlayerPage(),
      ),
    );
    await tester.pump();
  }

  group('layout', () {
    testWidgets('does not overflow on a small phone', (
      WidgetTester tester,
    ) async {
      // The reported bug: the speed chips wrapped onto a second row and the
      // column ran 11 pixels past the bottom of the screen.
      await pumpPlayer(tester, trackCount: 1, size: const Size(320, 560));

      expect(tester.takeException(), isNull);
    });

    testWidgets('does not overflow at a large text scale', (
      WidgetTester tester,
    ) async {
      await pumpPlayer(
        tester,
        trackCount: 3,
        size: const Size(320, 560),
        textScale: 2,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('scrolls when it cannot all fit', (WidgetTester tester) async {
      await pumpPlayer(
        tester,
        trackCount: 1,
        size: const Size(320, 400),
        textScale: 1.6,
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('skip controls', () {
    testWidgets('a single file gets no skip buttons', (
      WidgetTester tester,
    ) async {
      await pumpPlayer(tester, trackCount: 1);

      expect(find.byIcon(Icons.skip_previous_rounded), findsNothing);
      expect(find.byIcon(Icons.skip_next_rounded), findsNothing);
    });

    testWidgets('a queue gets both, with the ends disabled', (
      WidgetTester tester,
    ) async {
      await pumpPlayer(tester, trackCount: 3);

      expect(find.byIcon(Icons.skip_previous_rounded), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      final IconButton previous = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_previous_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(
        previous.onPressed,
        isNull,
        reason: 'there is nothing before the first track',
      );

      final IconButton next = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.skip_next_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(next.onPressed, isNotNull);
    });

    testWidgets('the queue position is shown', (WidgetTester tester) async {
      await pumpPlayer(tester, trackCount: 4, startIndex: 1);

      expect(find.text('Track 2 of 4'), findsOneWidget);
    });

    testWidgets('a single file shows no position line', (
      WidgetTester tester,
    ) async {
      await pumpPlayer(tester, trackCount: 1);

      expect(find.textContaining('Track '), findsNothing);
    });
  });
}
