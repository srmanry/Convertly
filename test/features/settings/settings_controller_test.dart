import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/settings/domain/entities/app_settings.dart';
import 'package:convertly/features/settings/domain/repositories/settings_repository.dart';
import 'package:convertly/features/settings/domain/usecases/get_settings.dart';
import 'package:convertly/features/settings/domain/usecases/save_settings.dart';
import 'package:convertly/features/settings/presentation/controllers/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeSettingsRepository implements SettingsRepository {
  _FakeSettingsRepository({this.stored = const AppSettings()});

  AppSettings stored;
  AppSettings? lastSaved;

  @override
  Future<Result<AppSettings>> getSettings() async =>
      Result<AppSettings>.success(stored);

  @override
  Future<Result<AppSettings>> saveSettings(AppSettings settings) async {
    lastSaved = settings;
    stored = settings;
    return Result<AppSettings>.success(settings);
  }
}

SettingsController buildController(SettingsRepository repository) {
  return SettingsController(GetSettings(repository), SaveSettings(repository));
}

void main() {
  test('load pulls the persisted settings into state', () async {
    final repository = _FakeSettingsRepository(
      stored: const AppSettings(themeMode: AppThemeMode.dark),
    );
    final SettingsController controller = buildController(repository);

    await controller.load();

    expect(controller.settings.value.themeMode, AppThemeMode.dark);
    expect(controller.isLoading.value, isFalse);
  });

  test('maps the stored theme onto Flutter ThemeMode', () async {
    final repository = _FakeSettingsRepository();
    final SettingsController controller = buildController(repository);

    expect(controller.themeMode, ThemeMode.system);

    repository.stored = const AppSettings(themeMode: AppThemeMode.light);
    await controller.load();
    expect(controller.themeMode, ThemeMode.light);

    repository.stored = const AppSettings(themeMode: AppThemeMode.dark);
    await controller.load();
    expect(controller.themeMode, ThemeMode.dark);
  });

  test('changing a default persists it and updates state', () async {
    final repository = _FakeSettingsRepository();
    final SettingsController controller = buildController(repository);

    await controller.setDefaultOutputFormat(AudioFormat.wav);

    expect(controller.settings.value.defaultOutputFormat, AudioFormat.wav);
    expect(repository.lastSaved?.defaultOutputFormat, AudioFormat.wav);
  });

  test('changing one preference leaves the others untouched', () async {
    final repository = _FakeSettingsRepository();
    final SettingsController controller = buildController(repository);

    await controller.setLanguageCode('bn');

    expect(controller.settings.value.languageCode, 'bn');
    expect(
      controller.settings.value.defaultOutputFormat,
      const AppSettings().defaultOutputFormat,
    );
  });
}
