import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A compact equalizer that moves during playback and rests when paused.
class AudioPlaybackWave extends StatefulWidget {
  const AudioPlaybackWave({required this.isPlaying, super.key});

  final bool isPlaying;

  @override
  State<AudioPlaybackWave> createState() => _AudioPlaybackWaveState();
}

class _AudioPlaybackWaveState extends State<AudioPlaybackWave>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4200),
    value: 0.15,
  );
  bool _reducedMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reducedMotion = MediaQuery.disableAnimationsOf(context);
    _syncPlayback();
  }

  @override
  void didUpdateWidget(AudioPlaybackWave oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying) {
      _syncPlayback();
    }
  }

  void _syncPlayback() {
    if (widget.isPlaying && !_reducedMotion) {
      if (!_motion.isAnimating) {
        _motion.repeat();
      }
    } else {
      _motion.stop();
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return ExcludeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SizedBox(
          width: double.infinity,
          height: 144,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _WavePainter(
                motion: _motion,
                primary: colors.primary,
                secondary: colors.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.motion,
    required this.primary,
    required this.secondary,
  }) : super(repaint: motion);

  final Animation<double> motion;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }

    final double phase = motion.value * math.pi * 2;
    final double centerY = size.height / 2;
    const int count = 11;
    final double spacing = math.min(12, size.width / (count + 2));
    final double strokeWidth = spacing * 0.5;
    final double startX = (size.width - (count - 1) * spacing) / 2;

    canvas.drawOval(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: count * spacing,
        height: 32,
      ),
      Paint()
        ..color = primary.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final Paint bar = Paint()
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < count; i++) {
      final double x = i / (count - 1);
      // Different rhythms keep the bars moving independently. Integer
      // frequencies make the animation loop without a visible jump.
      final double pulse = (math.sin(phase * (2 + i % 3) + i * 1.37) + 1) / 2;
      final double sway = (math.sin(phase + i * 0.7) + 1) / 2;
      final double energy = pulse * 0.65 + sway * 0.35;
      final double envelope = 0.65 + math.sin(x * math.pi) * 0.35;
      final double halfHeight = 6 + envelope * (size.height * 0.25) * energy;
      final double dx = startX + i * spacing;
      bar.color = Color.lerp(primary, secondary, x)!;
      canvas.drawLine(
        Offset(dx, centerY - halfHeight),
        Offset(dx, centerY + halfHeight),
        bar,
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
