import 'package:convertly/core/routes/app_pages.dart';
import 'package:convertly/core/routes/app_routes.dart';
import 'package:convertly/core/startup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  test('a returning user lands in the app itself', () {
    expect(startRoute(onboardingCompleted: true), AppRoutes.shell);
  });

  test('a first run lands in onboarding', () {
    expect(startRoute(onboardingCompleted: false), AppRoutes.onboarding);
  });

  test('both start destinations exist in the route table', () {
    // A start route with no page behind it leaves the app on a blank screen
    // with no way out, and only on a device where that branch is taken.
    final Set<String> routes = AppPages.pages
        .map((GetPage<dynamic> page) => page.name)
        .toSet();

    expect(routes, containsAll(<String>[AppRoutes.shell, AppRoutes.onboarding]));
  });

  test('nothing waits on a branding screen any more', () {
    // The app used to open on a Dart splash screen that held the user for a
    // fixed 1800ms on top of the native splash. Both the screen and the wait
    // are gone; this fails if either comes back.
    expect(
      AppPages.pages.any(
        (GetPage<dynamic> page) => page.name.contains('splash'),
      ),
      isFalse,
    );
  });
}
