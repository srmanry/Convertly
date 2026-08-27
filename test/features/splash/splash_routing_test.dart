import 'package:convertly/core/constants/app_constants.dart';
import 'package:convertly/core/routes/app_routes.dart';
import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/features/splash/presentation/bindings/splash_binding.dart';
import 'package:convertly/features/splash/presentation/pages/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exercises the real SplashBinding through the real route table.
///
/// Regression cover for the splash hanging forever: SplashPage never calls
/// Get.find, so a lazily registered controller was never constructed and its
/// onReady never ran.
Future<void> pumpSplashFlow(
  WidgetTester tester, {
  required bool onboardingCompleted,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (onboardingCompleted) 'onboarding_completed': true,
  });
  Get.put<StorageService>(await StorageService.init(), permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.splash,
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
          name: AppRoutes.splash,
          page: SplashPage.new,
          binding: SplashBinding(),
        ),
        GetPage<void>(
          name: AppRoutes.onboarding,
          page: () => const Scaffold(body: Text('onboarding-route')),
        ),
        GetPage<void>(
          name: AppRoutes.shell,
          page: () => const Scaffold(body: Text('shell-route')),
        ),
      ],
    ),
  );

  // Let the branding show, then run past the minimum splash hold.
  await tester.pump();
  await tester.pump(AppConstants.splashDuration + const Duration(seconds: 1));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  testWidgets('a first run leaves the splash for onboarding', (
    WidgetTester tester,
  ) async {
    await pumpSplashFlow(tester, onboardingCompleted: false);

    expect(find.byType(SplashPage), findsNothing);
    expect(find.text('onboarding-route'), findsOneWidget);
  });

  testWidgets('a returning user leaves the splash for the shell', (
    WidgetTester tester,
  ) async {
    await pumpSplashFlow(tester, onboardingCompleted: true);

    expect(find.byType(SplashPage), findsNothing);
    expect(find.text('shell-route'), findsOneWidget);
  });
}
