import 'package:equatable/equatable.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';

/// How the app should follow the platform theme.
enum AppThemeMode { system, light, dark }

/// All user-configurable preferences.
class AppSettings extends Equatable {
  const AppSettings({
    this.themeMode = AppThemeMode.system,
    this.defaultOutputFormat = AudioFormat.mp3,
    this.defaultAudioQuality = AudioQuality.kbps192,
    this.outputFolder,
    this.languageCode = 'en',
  });

  final AppThemeMode themeMode;
  final AudioFormat defaultOutputFormat;
  final AudioQuality defaultAudioQuality;

  /// Absolute path of the output directory. `null` means "app default", which
  /// is resolved at conversion time rather than stored, so the value stays
  /// valid across reinstalls and OS storage changes.
  final String? outputFolder;

  final String languageCode;

  AppSettings copyWith({
    AppThemeMode? themeMode,
    AudioFormat? defaultOutputFormat,
    AudioQuality? defaultAudioQuality,
    String? outputFolder,
    String? languageCode,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      defaultOutputFormat: defaultOutputFormat ?? this.defaultOutputFormat,
      defaultAudioQuality: defaultAudioQuality ?? this.defaultAudioQuality,
      outputFolder: outputFolder ?? this.outputFolder,
      languageCode: languageCode ?? this.languageCode,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    themeMode,
    defaultOutputFormat,
    defaultAudioQuality,
    outputFolder,
    languageCode,
  ];
}
