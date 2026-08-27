/// Values that identify the product itself.
abstract final class AppConstants {
  static const String appName = 'Convertly';
  static const String appTagline = 'Media Converter & Toolkit';

  /// Folder created inside the app-specific media directory for all output.
  static const String outputFolderName = 'Convertly';

  static const Duration splashDuration = Duration(milliseconds: 1800);
}

/// Keys used for local key-value persistence.
///
/// Centralised so a rename cannot silently orphan stored data.
abstract final class StorageKeys {
  static const String onboardingCompleted = 'onboarding_completed';
  static const String themeMode = 'settings_theme_mode';
  static const String defaultOutputFormat = 'settings_default_output_format';
  static const String defaultAudioQuality = 'settings_default_audio_quality';
  static const String outputFolder = 'settings_output_folder';
  static const String languageCode = 'settings_language_code';
}
