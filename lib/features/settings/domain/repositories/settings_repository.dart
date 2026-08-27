import '../../../../core/types/result.dart';
import '../entities/app_settings.dart';

abstract interface class SettingsRepository {
  /// Loads persisted settings, falling back to defaults for missing values.
  Future<Result<AppSettings>> getSettings();

  /// Persists the full settings object.
  Future<Result<AppSettings>> saveSettings(AppSettings settings);
}
