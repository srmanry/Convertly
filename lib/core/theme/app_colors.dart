import 'package:flutter/material.dart';

/// The neon violet, blue and pink palette used throughout the app.
abstract final class AppColors {
  static const Color seed = Color(0xFF9B4DFF);

  static const Color accentAudio = Color(0xFF35D9FF);
  static const Color accentVideo = Color(0xFFFF4FC3);
  static const Color accentTools = Color(0xFF8B6CFF);
  static const Color accentPremium = Color(0xFFFFC857);

  static const Color success = Color(0xFF42E8A4);
  static const Color warning = Color(0xFFFFC857);
  static const Color danger = Color(0xFFC9364A);

  /// Cycled across the mixer's tracks so each one reads as a distinct voice
  /// without introducing any colour the rest of the app does not already use
  /// for an accent — the same six that label the tools on the home screen.
  static const List<Color> mixTrackAccents = <Color>[
    accentAudio,
    success,
    accentPremium,
    accentTools,
    accentVideo,
    Color(0xFF6F9BFF),
  ];

  static const List<Color> brandGradient = <Color>[
    Color(0xFFE13CFF),
    Color(0xFF8B5CFF),
    Color(0xFF2D8CFF),
  ];

  static const List<Color> darkBackgroundGradient = <Color>[
    Color(0xFF100B2B),
    Color(0xFF28114C),
    Color(0xFF102556),
  ];

  static const List<Color> lightBackgroundGradient = <Color>[
    Color(0xFFFCF8FF),
    Color(0xFFF0E2FF),
    Color(0xFFDCEBFF),
  ];

  static List<Color> backgroundGradient(Brightness brightness) =>
      brightness == Brightness.dark
      ? darkBackgroundGradient
      : lightBackgroundGradient;
}
