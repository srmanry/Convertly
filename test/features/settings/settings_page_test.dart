import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/settings/domain/entities/app_settings.dart';
import 'package:convertly/features/settings/domain/repositories/settings_repository.dart';
import 'package:convertly/features/settings/domain/usecases/get_settings.dart';
import 'package:convertly/features/settings/domain/usecases/save_settings.dart';
import 'package:convertly/features/settings/presentation/controllers/settings_controller.dart';
import 'package:convertly/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeSettingsRepository implements SettingsRepository {
  AppSettings stored = const AppSettings();

  @override
  Future<Result<AppSettings>> getSettings() async =>
      Result<AppSettings>.success(stored);

  @override
  Future<Result<AppSettings>> saveSettings(AppSettings settings) async {
    stored = settings;
    return Result<AppSettings>.success(settings);
  }
}

void main() {
  late _FakeSettingsRepository repository;

  setUp(() {
    repository = _FakeSettingsRepository();
    Get.put<SettingsController>(
      SettingsController(GetSettings(repository), SaveSettings(repository)),
    );
  });

  tearDown(Get.reset);

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(theme: AppTheme.light, home: const SettingsPage()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders every settings section', (WidgetTester tester) async {
    await pumpSettings(tester);

    // The list is lazily built, so later sections must be scrolled into view.
    for (final String section in <String>[
      'APPEARANCE',
      'CONVERSION',
      'STORAGE',
      'APP',
      'OTHER',
    ]) {
      await tester.scrollUntilVisible(
        find.text(section),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(section), findsOneWidget);
    }
  });

  testWidgets('shows the current preference values', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text('System'), findsOneWidget);
    expect(find.text('MP3'), findsOneWidget);
    expect(find.text('192 kbps'), findsOneWidget);
  });

  testWidgets('picking a theme persists it and updates the row', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Theme'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Dark').last);
    await tester.pumpAndSettle();

    expect(repository.stored.themeMode, AppThemeMode.dark);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('picking an output format persists it', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text('Default output format'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WAV').last);
    await tester.pumpAndSettle();

    expect(repository.stored.defaultOutputFormat.label, 'WAV');
  });
}
