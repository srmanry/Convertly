import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/presentation/widgets/timeline_scrollbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  tearDown(Get.reset);

  testWidgets(
    'handoff between attached views reads and moves only the newest position',
    (tester) async {
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        GetMaterialApp(
          theme: AppTheme.dark,
          translations: AppTranslations(),
          locale: const Locale('en'),
          home: Scaffold(
            body: SizedBox(
              width: 200,
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < 2; i++)
                    SingleChildScrollView(
                      controller: controller,
                      scrollDirection: Axis.horizontal,
                      child: const SizedBox(width: 800, height: 30),
                    ),
                  TimelineScrollbar(
                    controller: controller,
                    viewportExtent: 200,
                    contentExtent: 800,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(controller.positions.length, 2);
      expect(tester.takeException(), isNull);
      await tester.drag(
        find.byKey(TimelineScrollbar.thumbKey),
        const Offset(40, 0),
      );
      await tester.pumpAndSettle();
      expect(controller.positions.first.pixels, 0);
      expect(controller.positions.last.pixels, greaterThan(0));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('controls are safe before a scrolling view attaches', (
    tester,
  ) async {
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        translations: AppTranslations(),
        locale: const Locale('en'),
        home: Scaffold(
          body: TimelineScrollbar(
            controller: controller,
            viewportExtent: 200,
            contentExtent: 800,
          ),
        ),
      ),
    );
    await tester.drag(
      find.byKey(TimelineScrollbar.thumbKey),
      const Offset(40, 0),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
