import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the app branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Convertly'), findsOneWidget);
    expect(find.text('Media Converter & Toolkit'), findsOneWidget);
  });

  testWidgets('releases its animation controller on dispose', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light, home: const SplashPage()),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Replacing the tree disposes SplashPage; a leaked ticker would make the
    // test fail with a "was disposed with an active Ticker" error.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(find.byType(SplashPage), findsNothing);
  });
}
