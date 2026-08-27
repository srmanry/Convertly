import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../models/app_settings_model.dart';

abstract interface class SettingsLocalDataSource {
  AppSettingsModel read();

  Future<void> write(AppSettingsModel settings);
}

class SettingsLocalDataSourceImpl implements SettingsLocalDataSource {
  const SettingsLocalDataSourceImpl(this._storage);

  final StorageService _storage;

  @override
  AppSettingsModel read() {
    return AppSettingsModel.fromStorage(
      themeMode: _storage.readString(StorageKeys.themeMode),
      outputFormat: _storage.readString(StorageKeys.defaultOutputFormat),
      audioQuality: _storage.readString(StorageKeys.defaultAudioQuality),
      outputFolder: _storage.readString(StorageKeys.outputFolder),
      languageCode: _storage.readString(StorageKeys.languageCode),
    );
  }

  @override
  Future<void> write(AppSettingsModel settings) async {
    await _writeOrRemove(StorageKeys.themeMode, settings.themeMode);
    await _writeOrRemove(
      StorageKeys.defaultOutputFormat,
      settings.outputFormat,
    );
    await _writeOrRemove(
      StorageKeys.defaultAudioQuality,
      settings.audioQuality,
    );
    await _writeOrRemove(StorageKeys.languageCode, settings.languageCode);
    await _writeOrRemove(StorageKeys.outputFolder, settings.outputFolder);
  }

  /// A null value clears the key rather than storing an empty string, so a
  /// later read falls back to the default instead of an invalid value.
  Future<void> _writeOrRemove(String key, String? value) {
    return value == null
        ? _storage.remove(key)
        : _storage.writeString(key, value);
  }
}
