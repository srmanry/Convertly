import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/home/presentation/controllers/home_controller.dart';
import 'package:convertly/features/home/presentation/pages/home_page.dart';
import 'package:convertly/features/shell/presentation/controllers/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get
      ..put<HomeController>(HomeController())
      ..put<ShellController>(ShellController());
  });

  tearDown(Get.reset);

  Future<void> pumpHome(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const HomePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Renders at a given logical screen size for the duration of the test.
  void useScreenSize(WidgetTester tester, Size size) {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = size * 3;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows both primary conversion actions', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Video to Audio'), findsOneWidget);
    expect(find.text('Extract audio from a video'), findsOneWidget);
    expect(find.text('Audio Converter'), findsOneWidget);
    expect(find.text('Convert audio between formats'), findsOneWidget);
  });

  testWidgets('shows the tools section', (WidgetTester tester) async {
    await pumpHome(tester);

    expect(find.text('Audio Cutter'), findsOneWidget);
    expect(find.text('Audio Merger'), findsOneWidget);
    expect(find.text('Audio Compressor'), findsOneWidget);
  });

  testWidgets('shows the empty state when nothing has been converted', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Your converted files will appear here.'), findsOneWidget);
  });

  testWidgets('greets the user and shows the app name', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Convertly'), findsOneWidget);
    expect(find.textContaining('Good '), findsOneWidget);
  });

  testWidgets('"See all" switches the shell to the Files tab', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    await tester.tap(find.text('See all'));
    await tester.pump();

    expect(Get.find<ShellController>().currentTab.value, ShellTab.files);
  });

  // Regression cover: the tools grid previously derived tile height from screen
  // width via childAspectRatio, so a two-line label overflowed on narrow
  // screens and at larger font scales.
  /// A two-line label rendered in full. Asserting only "no overflow" is too
  /// weak: Flexible suppresses the exception by clipping the label instead.
  void expectTwoLineLabelFullyVisible(WidgetTester tester, double textScale) {
    final Size labelSize = tester.getSize(find.text('Audio Compressor'));
    final double oneLine = 14 * 1.3 * textScale;

    expect(
      labelSize.height,
      greaterThan(oneLine * 1.5),
      reason: 'the label is clipped instead of showing both lines',
    );
  }

  testWidgets('tools grid does not clip labels on a narrow screen', (
    WidgetTester tester,
  ) async {
    useScreenSize(tester, const Size(320, 640));

    await pumpHome(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('Audio Compressor'), findsOneWidget);
    expectTwoLineLabelFullyVisible(tester, 1);
  });

  testWidgets('tools grid does not clip labels at a large text scale', (
    WidgetTester tester,
  ) async {
    useScreenSize(tester, const Size(360, 720));

    await pumpHome(tester, textScale: 1.5);

    expect(tester.takeException(), isNull);
    expectTwoLineLabelFullyVisible(tester, 1.5);
  });

  testWidgets('tool labels are named consistently', (
    WidgetTester tester,
  ) async {
    await pumpHome(tester);

    expect(find.text('Audio Cutter'), findsOneWidget);
    expect(find.text('Audio Merger'), findsOneWidget);
    expect(find.text('Audio Compressor'), findsOneWidget);
  });
}
