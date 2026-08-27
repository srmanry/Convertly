import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../domain/entities/app_settings.dart';

/// Storage representation of [AppSettings].
///
/// Deliberately a separate class rather than a subclass of the entity: an
/// Equatable subclass never compares equal to its parent, which would make a
/// loaded model silently differ from an equivalent entity.
///
/// Enums are persisted by name rather than index, so reordering an enum cannot
/// change a user's saved preference.
class AppSettingsModel {
  const AppSettingsModel({
    required this.themeMode,
    required this.outputFormat,
    required this.audioQuality,
    required this.outputFolder,
    required this.languageCode,
  });

  factory AppSettingsModel.fromEntity(AppSettings settings) {
    return AppSettingsModel(
      themeMode: settings.themeMode.name,
      outputFormat: settings.defaultOutputFormat.name,
      audioQuality: settings.defaultAudioQuality.name,
      outputFolder: settings.outputFolder,
      languageCode: settings.languageCode,
    );
  }

  /// Builds a model from raw stored strings. Every field is nullable because
  /// any of them may be absent on a first run or after an upgrade.
  factory AppSettingsModel.fromStorage({
    String? themeMode,
    String? outputFormat,
    String? audioQuality,
    String? outputFolder,
    String? languageCode,
  }) {
    return AppSettingsModel(
      themeMode: themeMode,
      outputFormat: outputFormat,
      audioQuality: audioQuality,
      outputFolder: outputFolder,
      languageCode: languageCode,
    );
  }

  final String? themeMode;
  final String? outputFormat;
  final String? audioQuality;
  final String? outputFolder;
  final String? languageCode;

  /// Maps to the domain entity, substituting a default for any value that is
  /// missing or no longer recognised.
  AppSettings toEntity() {
    return AppSettings(
      themeMode: _parseThemeMode(themeMode),
      defaultOutputFormat: AudioFormat.fromName(outputFormat),
      defaultAudioQuality: AudioQuality.fromName(audioQuality),
      outputFolder: outputFolder,
      languageCode: languageCode ?? const AppSettings().languageCode,
    );
  }

  static AppThemeMode _parseThemeMode(String? name) {
    return AppThemeMode.values.firstWhere(
      (AppThemeMode mode) => mode.name == name,
      orElse: () => AppThemeMode.system,
    );
  }
}
