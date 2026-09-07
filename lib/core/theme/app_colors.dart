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
