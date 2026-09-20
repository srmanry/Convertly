import 'dart:async';

import 'package:convertly/core/i18n/app_translations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs once before the tests in this suite, and applies to all of them.
///
/// Loads the app's strings so widgets render real sentences: a test that
/// pumps a single screen, rather than the whole app, would otherwise see
/// translation keys and every assertion about what is on screen would fail.
///
/// Before each test rather than once, because `Get.reset()` in a teardown
/// clears the strings along with everything else GetX holds.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUp(AppTranslations.install);
  AppTranslations.install();
  await testMain();
}
