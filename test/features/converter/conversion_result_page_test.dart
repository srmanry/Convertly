import 'dart:async';

import 'package:convertly/core/routes/app_routes.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/converter/domain/entities/conversion_result.dart';
import 'package:convertly/features/converter/presentation/pages/conversion_result_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

const ConversionResult _result = ConversionResult(
  outputPath: '/out/a.mp3',
  name:
      'vidssave.com Tumi Amar Emoni _ তুমি আমার এমনই _ HD _ Salman '
      'Shah, Shabnur & Karchi _ Kanak Chapa _ Anondo Osru 48KBPS_cu.mp3',
  sizeInBytes: 1200000,
  format: 'MP3',
  duration: Duration(seconds: 51),
);

void main() {
  tearDown(Get.reset);

  Future<void> pumpAt(
    WidgetTester tester,
    Size size, {
    Object? arguments = _result,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        home: const SizedBox.shrink(),
        getPages: <GetPage<dynamic>>[
          GetPage<dynamic>(
            name: '/result',
            page: () => const ConversionResultPage(),
          ),
          GetPage<dynamic>(
            name: AppRoutes.audioPlayer,
            page: () => const Scaffold(body: Text('Player')),
          ),
        ],
      ),
    );
    unawaited(Get.toNamed<void>('/result', arguments: arguments));
    await tester.pumpAndSettle();
  }

  testWidgets('result keeps its own data when the player opens with a map', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(430, 1000));
    await tester.tap(find.text('Play Audio'));
    await tester.pumpAndSettle();

    expect(Get.arguments, <String, String>{
      'path': _result.outputPath,
      'title': _result.name,
    });
    // An underlying route can rebuild after a theme or viewport change even
    // while Get.arguments belongs to the player on top of it.
    tester
        .element(find.byType(ConversionResultPage, skipOffstage: false))
        .markNeedsBuild();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text(_result.name, skipOffstage: false), findsOneWidget);

    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text(_result.name), findsOneWidget);
    expect(find.text('Play Audio'), findsOneWidget);
  });

  for (final Object? arguments in <Object?>[
    null,
    <String, String>{'path': '/out/a.mp3', 'title': 'A'},
  ]) {
    testWidgets(
      'invalid result arguments $arguments recover without crashing',
      (WidgetTester tester) async {
        await pumpAt(tester, const Size(390, 700), arguments: arguments);

        expect(tester.takeException(), isNull);
        expect(find.text('Go Back'), findsOneWidget);
        expect(find.text('Play Audio'), findsNothing);
      },
    );
  }

  testWidgets('a short screen scrolls instead of overflowing', (
    WidgetTester tester,
  ) async {
    // The phone in the report: everything did not fit and the bottom
    // overflowed by 19 pixels.
    await pumpAt(tester, const Size(390, 700));

    expect(tester.takeException(), isNull);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
  });

  testWidgets('a very short screen still scrolls to the last button', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(360, 480));

    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Done'), 100);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('a tall screen lays out without error', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(430, 1000));

    expect(tester.takeException(), isNull);
    expect(find.text('Play Audio'), findsOneWidget);
  });

  testWidgets('a long file name stops at two lines', (
    WidgetTester tester,
  ) async {
    await pumpAt(tester, const Size(390, 900));

    final Text name = tester.widget<Text>(
      find.textContaining('vidssave.com Tumi Amar'),
    );
    expect(name.maxLines, 2);
    expect(name.overflow, TextOverflow.ellipsis);

    final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
      find.textContaining('vidssave.com Tumi Amar'),
    );
    expect(
      paragraph.size.height,
      lessThanOrEqualTo(paragraph.text.style!.fontSize! * 2 * 1.6),
    );
  });
}
