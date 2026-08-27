/// Named routes. Referenced everywhere instead of raw strings.
abstract final class AppRoutes {
  static const String splash = '/splash';
  static const String onboarding = '/onboarding';

  /// The bottom-navigation shell that hosts Home, Files, Tools and Settings.
  static const String shell = '/';

  static const String settings = '/settings';

  /// Shared conversion screen; the tool is passed as an argument.
  static const String converter = '/converter';
  static const String conversionResult = '/conversion-result';

  static const String audioPlayer = '/audio-player';
}
