import 'package:convertly/core/enums/audio_format.dart';
import 'package:convertly/core/enums/audio_quality.dart';
import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/features/settings/data/datasources/settings_local_datasource.dart';
import 'package:convertly/features/settings/data/models/app_settings_model.dart';
import 'package:convertly/features/settings/data/repositories/settings_repository_impl.dart';
import 'package:convertly/features/settings/domain/entities/app_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsRepositoryImpl> buildRepository([
  Map<String, Object> initialValues = const <String, Object>{},
]) async {
  SharedPreferences.setMockInitialValues(initialValues);
  final StorageService storage = await StorageService.init();
  return SettingsRepositoryImpl(SettingsLocalDataSourceImpl(storage));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppSettingsModel', () {
    test('falls back to defaults for missing values', () {
      final AppSettings settings = AppSettingsModel.fromStorage().toEntity();

      expect(settings, const AppSettings());
    });

    test('ignores values that no longer map to a known enum', () {
      final AppSettings settings = AppSettingsModel.fromStorage(
        themeMode: 'sepia',
        outputFormat: 'flac',
        audioQuality: 'kbps64',
      ).toEntity();

      expect(settings.themeMode, AppThemeMode.system);
      expect(settings.defaultOutputFormat, AudioFormat.mp3);
      expect(settings.defaultAudioQuality, AudioQuality.kbps192);
    });

    test('maps an entity to storage strings and back unchanged', () {
      const AppSettings original = AppSettings(
        themeMode: AppThemeMode.dark,
        defaultOutputFormat: AudioFormat.m4a,
        defaultAudioQuality: AudioQuality.kbps256,
        outputFolder: '/tmp/out',
        languageCode: 'bn',
      );

      expect(AppSettingsModel.fromEntity(original).toEntity(), original);
    });
  });

  group('SettingsRepositoryImpl', () {
    test('returns defaults when nothing has been stored yet', () async {
      final SettingsRepositoryImpl repository = await buildRepository();

      final AppSettings? settings =
          (await repository.getSettings()).valueOrNull;

      expect(settings, const AppSettings());
    });

    test('round-trips settings through storage', () async {
      final SettingsRepositoryImpl repository = await buildRepository();
      const AppSettings updated = AppSettings(
        themeMode: AppThemeMode.dark,
        defaultOutputFormat: AudioFormat.wav,
        defaultAudioQuality: AudioQuality.kbps320,
        languageCode: 'bn',
      );

      final saved = await repository.saveSettings(updated);
      final reloaded = await repository.getSettings();

      expect(saved.isSuccess, isTrue);
      expect(reloaded.valueOrNull, updated);
    });

    test('clears a previously stored output folder when it is unset', () async {
      final SettingsRepositoryImpl repository = await buildRepository();

      await repository.saveSettings(
        const AppSettings(outputFolder: '/storage/emulated/0/Convertly'),
      );
      expect(
        (await repository.getSettings()).valueOrNull?.outputFolder,
        '/storage/emulated/0/Convertly',
      );

      await repository.saveSettings(const AppSettings());

      expect(
        (await repository.getSettings()).valueOrNull?.outputFolder,
        isNull,
      );
    });

    test('reads back enum choices by name, not index', () async {
      final SettingsRepositoryImpl repository =
          await buildRepository(<String, Object>{
            'settings_theme_mode': 'light',
            'settings_default_output_format': 'm4a',
            'settings_default_audio_quality': 'kbps96',
          });

      final AppSettings? settings =
          (await repository.getSettings()).valueOrNull;

      expect(settings?.themeMode, AppThemeMode.light);
      expect(settings?.defaultOutputFormat, AudioFormat.m4a);
      expect(settings?.defaultAudioQuality, AudioQuality.kbps96);
    });
  });
}
