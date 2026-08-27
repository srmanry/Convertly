import 'package:flutter/material.dart';

/// Brand colours. Everything else is derived by [ColorScheme.fromSeed] so the
/// palette stays Material 3 compliant in both light and dark mode.
abstract final class AppColors {
  static const Color seed = Color(0xFF6C4DF6);

  static const Color accentAudio = Color(0xFF00B8A9);
  static const Color accentVideo = Color(0xFFFF7A59);
  static const Color accentTools = Color(0xFF3D8BFD);
  static const Color accentPremium = Color(0xFFFFB020);

  static const Color success = Color(0xFF2E9E5B);
  static const Color warning = Color(0xFFE0A800);

  static const List<Color> brandGradient = <Color>[
    Color(0xFF6C4DF6),
    Color(0xFF9B6BFF),
  ];
}
