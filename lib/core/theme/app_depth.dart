import 'package:flutter/material.dart';

/// Depth tokens that give the flat neon surfaces a lit, three-dimensional read.
///
/// Every raised surface in the app is lit by a single imaginary light sitting
/// above and to the left. That one rule is what makes the highlights and
/// shadows agree with each other instead of looking like unrelated decoration:
/// the lit edge always faces the light, the shadow always falls away from it.
abstract final class AppDepth {
  /// Where the imaginary light sits, as a fraction of the surface.
  static const Alignment lightSource = Alignment(-0.9, -1);

  /// Where the shadow falls, mirroring [lightSource].
  static const Alignment shadowSide = Alignment(0.9, 1);

  static Color _shadow(bool isDark) =>
      isDark ? const Color(0xFF04000E) : const Color(0xFF3B2757);

  /// Shadow stack for a surface floating [elevation] logical steps up.
  ///
  /// Two shadows rather than one: a tight contact shadow that anchors the
  /// surface to whatever is behind it, and a wide ambient shadow that carries
  /// the sense of height. A single blur reads as a blurred sticker; the pair
  /// reads as an object standing off the background.
  static List<BoxShadow> lift({
    required bool isDark,
    double elevation = 1,
    Color? tint,
  }) {
    final Color base = _shadow(isDark);
    final double contactAlpha = (isDark ? 0.5 : 0.14) * elevation;
    final double ambientAlpha = (isDark ? 0.34 : 0.1) * elevation;

    return <BoxShadow>[
      // Contact: short, dark, barely offset. Glues the surface down.
      BoxShadow(
        color: base.withValues(alpha: contactAlpha.clamp(0, 0.6)),
        blurRadius: 3 * elevation,
        offset: Offset(0, 1.5 * elevation),
      ),
      // Ambient: long and soft. Carries the height.
      BoxShadow(
        color: base.withValues(alpha: ambientAlpha.clamp(0, 0.45)),
        blurRadius: 22 * elevation,
        spreadRadius: -2,
        offset: Offset(1.5 * elevation, 10 * elevation),
      ),
      // Optional accent bounce: colour thrown back onto the background by a
      // tinted surface, the way a coloured object bleeds onto the table.
      if (tint != null)
        BoxShadow(
          color: tint.withValues(alpha: (isDark ? 0.2 : 0.14) * elevation),
          blurRadius: 26 * elevation,
          spreadRadius: -6,
          offset: Offset(0, 8 * elevation),
        ),
    ];
  }

  /// Face shading for a raised surface: lighter where the light lands,
  /// darker on the side turned away from it.
  static LinearGradient face({required bool isDark, Color? tint}) {
    // The lit end is white carrying only a trace of the tint — light picking
    // up the surface's colour, not the colour itself. Painting the accent here
    // at full strength floods the card and kills the sense of a light source.
    final Color lit = Color.lerp(
      Colors.white,
      tint ?? Colors.white,
      0.18,
    )!.withValues(alpha: isDark ? 0.07 : 0.4);
    final Color unlit = (isDark ? Colors.black : const Color(0xFF6A5385))
        .withValues(alpha: isDark ? 0.2 : 0.06);

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[lit, Colors.transparent, unlit],
      stops: const <double>[0, 0.38, 1],
    );
  }

  /// A convex cap: bright crown at the top-left falling to a shaded underside,
  /// which is what makes a small chip read as domed rather than printed.
  ///
  /// Opaque on purpose. A translucent dome samples whatever card sits behind
  /// it, so the same accent came out vivid on a dark surface and washed-out
  /// pastel on a light one.
  static LinearGradient dome(Color color, {required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        Color.lerp(color, Colors.white, isDark ? 0.3 : 0.34)!,
        color,
        Color.lerp(color, Colors.black, isDark ? 0.34 : 0.26)!,
      ],
      stops: const <double>[0, 0.52, 1],
    );
  }

  /// Ink for anything drawn on a [dome] of [color] — white on a dark accent,
  /// near-black on a bright one, so a yellow chip stays as legible as a violet
  /// one.
  static Color onDome(Color color) =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark
      ? Colors.white
      : Color.lerp(color, Colors.black, 0.72)!;

  /// Inner shading for a surface pressed *into* the background — the inverse
  /// of [face], used for wells and pressed states.
  static LinearGradient well({required bool isDark}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[
        (isDark ? Colors.black : const Color(0xFF5B4678)).withValues(
          alpha: isDark ? 0.34 : 0.12,
        ),
        Colors.transparent,
        Colors.white.withValues(alpha: isDark ? 0.06 : 0.5),
      ],
      stops: const <double>[0, 0.6, 1],
    );
  }

  /// Hairline that catches the light along the top edge of a raised surface.
  static Color rim(bool isDark) =>
      Colors.white.withValues(alpha: isDark ? 0.16 : 0.75);

  /// How far a surface tips toward the finger, in radians at full press.
  static const double tiltRadians = 0.055;

  /// Scale a surface settles to while held.
  static const double pressedScale = 0.972;

  /// Perspective strength for the tilt matrix. Smaller denominators exaggerate;
  /// 900 keeps the effect readable without looking like a fisheye.
  static const double perspective = 1 / 900;

  static const Duration pressDuration = Duration(milliseconds: 130);
  static const Duration releaseDuration = Duration(milliseconds: 320);
}
