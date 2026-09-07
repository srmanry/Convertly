import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// A frosted panel: what is behind it is blurred and shows through.
///
/// The blur only has something to work on where content actually sits behind
/// the panel, so this is worth using on bars that overlap the page — not on
/// something opaque that happens to want a tint.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    required this.child,
    super.key,
    this.blur = 22,
    this.borderRadius = BorderRadius.zero,
    this.topRim = true,
  });

  final Widget child;
  final double blur;
  final BorderRadius borderRadius;

  /// Draws the lit edge along the top, matching the single light source the
  /// rest of the app is built around.
  final bool topRim;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme colors = theme.colorScheme;

    return ClipRRect(
      // BackdropFilter samples without bound unless it is clipped, which on
      // some backends smears the blur across the whole screen.
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Translucent, not tinted: glass reads as glass because the page
            // shows through it, and an opaque fill here would waste the blur.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                colors.surfaceContainerLow.withValues(
                  alpha: isDark ? 0.6 : 0.7,
                ),
                colors.surfaceContainerLow.withValues(
                  alpha: isDark ? 0.78 : 0.86,
                ),
              ],
            ),
            border: topRim
                ? Border(
                    top: BorderSide(
                      color: Colors.white.withValues(alpha: isDark ? 0.1 : 0.6),
                      width: 0.5,
                    ),
                  )
                : null,
            borderRadius: borderRadius,
          ),
          child: child,
        ),
      ),
    );
  }
}
