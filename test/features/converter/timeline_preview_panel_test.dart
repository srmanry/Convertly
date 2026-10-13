import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/presentation/widgets/clip_timeline_strip.dart';
import 'package:convertly/features/converter/presentation/widgets/timeline_preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);
  bool toggled = false;
  const List<TimelineClip> clips = <TimelineClip>[
    TimelineClip(
      label: '1',
      name: 'Morning recording.mp3',
      start: Duration.zero,
      length: Duration(seconds: 40),
    ),
    TimelineClip(
      label: '2',
      name: 'Background music.mp3',
      start: Duration(seconds: 40),
      length: Duration(seconds: 20),
    ),
  ];

  Future<void> pump(
    WidgetTester tester, {
    bool playing = false,
    bool preparing = false,
    double width = 390,
    double scale = 1,
    String locale = 'en',
    bool dark = true,
  }) async {
    toggled = false;
    tester.view.physicalSize = Size(width, 850);
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
            child: TimelinePreviewPanel(
              clips: clips,
              total: const Duration(minutes: 1),
              position: const Duration(seconds: 45),
              isPlaying: playing,
              isPreparing: preparing,
              onPreview: () => toggled = true,
              onReorder: (_, _) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('preview control toggles playback and shows elapsed time', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('0:00'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    expect(find.text('Morning recording.mp3'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey<String>('timeline-preview-toggle')),
    );
    expect(toggled, isTrue);
    await pump(tester, playing: true);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('0:45'), findsOneWidget);
    expect(find.text('0:45 / 1:00'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'preparing shows progress and prevents duplicate preview requests',
    (tester) async {
      await pump(tester, preparing: true);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey<String>('timeline-preview-toggle')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final String locale in <String>['en', 'bn', 'hi']) {
    for (final bool dark in <bool>[true, false]) {
      testWidgets(
        'panel fits 320px with large $locale text in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          await pump(
            tester,
            width: 320,
            scale: 1.5,
            locale: locale,
            dark: dark,
          );
          expect(find.byType(ClipTimelineStrip), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
