import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/media_info.dart';
import 'package:convertly/features/converter/presentation/widgets/mix_track_list.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);
  final MediaInfo media = MediaInfo(
    path: '/music/recording.mp3',
    name: 'A very long recording name.mp3',
    extension: 'mp3',
    sizeInBytes: 1024,
    hasAudio: true,
    hasVideo: false,
    duration: const Duration(seconds: 90),
  );
  (Duration, Duration)? trimmed;
  int? removed;
  int? previewed;
  (int, int)? reordered;

  Future<void> pump(
    WidgetTester tester, {
    double width = 360,
    double scale = 1,
    bool dark = true,
    String locale = 'en',
    bool playing = false,
    bool twoClips = false,
  }) async {
    trimmed = null;
    removed = null;
    previewed = null;
    reordered = null;
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: Locale(locale),
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: MixTrackList(
              sources: <MediaInfo>[media, if (twoClips) media],
              volumes: const <double>[],
              starts: const <Duration>[Duration.zero, Duration(seconds: 30)],
              onVolumeChanged: null,
              showsPositions: true,
              trimRanges: const <(Duration, Duration)>[
                (Duration(seconds: 10), Duration(seconds: 40)),
              ],
              onTrimChanged: (_, start, end) => trimmed = (start, end),
              onPreviewClip: (index) => previewed = index,
              previewingClip: playing ? 0 : null,
              onRemove: (index) => removed = index,
              onReorder: (from, to) => reordered = (from, to),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('trim, reset, preview and remove address the selected clip', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Start'), findsNothing);
    expect(find.text('End'), findsNothing);
    expect(find.text('Trim selection'), findsNothing);
    await tester.tap(find.byTooltip('Play'));
    expect(previewed, 0);
    await tester.tap(find.byTooltip('Reset'));
    expect(trimmed, (Duration.zero, const Duration(seconds: 90)));
    trimmed = null;
    final Rect slider = tester.getRect(find.byType(RangeSlider));
    await tester.dragFrom(
      Offset(slider.left + 48, slider.center.dy),
      const Offset(20, 0),
    );
    await tester.pumpAndSettle();
    expect(trimmed, isNotNull);
    expect(reordered, isNull);
    await tester.tap(find.byTooltip('Remove'));
    expect(removed, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'dragging header padding reorders immediately without changing trim',
    (tester) async {
      await pump(tester, twoClips: true);
      expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
      final gesture = await tester.startGesture(
        tester.getTopLeft(find.byType(ReorderableDragStartListener).first) +
            const Offset(100, 3),
      );
      for (int step = 0; step < 20; step++) {
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
      expect(reordered, (0, 1));
      expect(trimmed, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('holding the card body reorders without an icon', (tester) async {
    await pump(tester, twoClips: true);
    final gesture = await tester.startGesture(
      tester.getTopLeft(
            find.byType(ReorderableDelayedDragStartListener).first,
          ) +
          const Offset(100, 2),
    );
    await tester.pump(const Duration(milliseconds: 600));
    for (int step = 0; step < 20; step++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(reordered, (0, 1));
    expect(trimmed, isNull);
    expect(tester.takeException(), isNull);
  });

  for (final String locale in <String>['en', 'bn', 'hi']) {
    for (final bool dark in <bool>[true, false]) {
      testWidgets('320px, large text, $locale, ${dark ? 'dark' : 'light'}', (
        tester,
      ) async {
        await pump(
          tester,
          width: 320,
          scale: 1.5,
          locale: locale,
          dark: dark,
          playing: true,
        );
        expect(find.byType(RangeSlider), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
