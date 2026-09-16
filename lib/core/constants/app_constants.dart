/// Values that identify the product itself.
abstract final class AppConstants {
  static const String appName = 'AudioForge';
  static const String appTagline = 'Media Converter & Toolkit';

  /// Folder created inside the app-specific media directory for all output.
  static const String outputFolderName = 'AudioForge';

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

  /// Ad-free files earned from a rewarded ad, so they survive the app closing.
  static const String adFreeExportsLeft = 'ads_free_exports_left';

  /// Ad-free files earned from a rewarded ad watched by choice.
  static const String adBonusExportsLeft = 'ads_bonus_exports_left';

  /// How far through the current round of ads the user is.
  static const String adCyclePosition = 'ads_cycle_position';
}
