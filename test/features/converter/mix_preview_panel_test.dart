import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/presentation/widgets/mix_preview_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);
  int presses = 0;

  Future<void> pumpPanel(
    WidgetTester tester, {
    bool playing = false,
    bool preparing = false,
    bool enabled = true,
    bool reducedMotion = false,
    double width = 390,
    double scale = 1,
    String locale = 'en',
    bool dark = true,
  }) async {
    tester.view.physicalSize = Size(width, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: Locale(locale),
        theme: dark ? AppTheme.dark : AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reducedMotion,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: MixPreviewPanel(
              total: const Duration(minutes: 4, seconds: 45),
              position: const Duration(seconds: 12),
              isPlaying: playing,
              isPreparing: preparing,
              onPreview: enabled ? () => presses++ : null,
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'single full-width button toggles playback and updates progress',
    (tester) async {
      presses = 0;
      await pumpPanel(tester);
      await tester.pumpAndSettle();
      expect(find.text('0:00'), findsOneWidget);
      expect(find.text('Preview'), findsOneWidget);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('mix-preview-equalizer')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byType(FilledButton)).width,
        tester
            .getSize(find.byKey(const ValueKey<String>('mix-preview-progress')))
            .width,
      );
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.byTooltip('Preview'));
      expect(presses, 1);

      await pumpPanel(tester, playing: true);
      final Future<void> reassembled = tester.binding.reassembleApplication();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await reassembled;
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.text('Stop'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        closeTo(12 / 285, 0.0001),
      );
      await tester.tap(find.byTooltip('Stop'));
      expect(presses, 2);

      await pumpPanel(tester);
      await tester.pumpAndSettle();
      expect(find.text('0:00'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'playback controls and time remain available with reduced motion',
    (tester) async {
      await pumpPanel(tester, playing: true);
      await pumpPanel(tester, playing: true, reducedMotion: true);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Stop'), findsOneWidget);
      expect(find.text('0:12'), findsOneWidget);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'loading and an empty mix prevent duplicate or invalid requests',
    (tester) async {
      await pumpPanel(tester, preparing: true);
      final Finder toggle = find.byKey(
        const ValueKey<String>('mix-preview-toggle'),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(toggle).onPressed, isNull);
      final ButtonStyle loadingStyle = tester
          .widget<FilledButton>(toggle)
          .style!;
      expect(
        loadingStyle.backgroundColor!.resolve(<WidgetState>{
          WidgetState.disabled,
        }),
        loadingStyle.backgroundColor!.resolve(<WidgetState>{}),
      );

      await pumpPanel(tester, enabled: false);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(toggle).onPressed, isNull);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  for (final String locale in <String>['en', 'bn', 'ar']) {
    for (final bool dark in <bool>[true, false]) {
      testWidgets(
        'fits narrow screens with large $locale text in ${dark ? 'dark' : 'light'} mode',
        (tester) async {
          await pumpPanel(
            tester,
            playing: true,
            width: 320,
            scale: 1.5,
            locale: locale,
            dark: dark,
          );
          expect(find.byType(MixPreviewPanel), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          expect(tester.binding.transientCallbackCount, 0);
        },
      );
    }
  }
}
