import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// App-wide atmospheric background inspired by neon music-player artwork.
class NeonBackdrop extends StatelessWidget {
  const NeonBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool isDark = brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.backgroundGradient(brightness),
          stops: const <double>[0, 0.52, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _Glow(
            alignment: const Alignment(1.35, -1.25),
            color: AppColors.accentVideo,
            opacity: isDark ? 0.2 : 0.12,
          ),
          _Glow(
            alignment: const Alignment(-1.4, 0.7),
            color: AppColors.accentAudio,
            opacity: isDark ? 0.14 : 0.1,
          ),
          // Vignette. Darkening the corners pushes the background further
          // behind the raised cards, which is what gives the stack its sense
          // of a foreground and a distance.
          const _Vignette(),
          child,
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    required this.alignment,
    required this.color,
    required this.opacity,
  });

  final Alignment alignment;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: FractionallySizedBox(
          widthFactor: 0.9,
          heightFactor: 0.55,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: <Color>[
                  color.withValues(alpha: opacity),
                  color.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            radius: 1.1,
            colors: <Color>[
              Colors.transparent,
              (isDark ? Colors.black : const Color(0xFF3B2757)).withValues(
                alpha: isDark ? 0.42 : 0.08,
              ),
            ],
            stops: const <double>[0.55, 1],
          ),
        ),
      ),
    );
  }
}
