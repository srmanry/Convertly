import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A decorative playback waveform; it does not measure the audio samples.
class MixPreviewWaveform extends StatefulWidget {
  const MixPreviewWaveform({required this.isPlaying, super.key});

  final bool isPlaying;

  @override
  State<MixPreviewWaveform> createState() => _MixPreviewWaveformState();
}

class _MixPreviewWaveformState extends State<MixPreviewWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant MixPreviewWaveform oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final bool animate =
        widget.isPlaying &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (animate) {
      if (!_motion.isAnimating) _motion.repeat();
    } else {
      _motion.reset();
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
    return RepaintBoundary(
      child: ExcludeSemantics(
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: CustomPaint(
            key: const ValueKey<String>('mix-preview-equalizer'),
            painter: _WaveformPainter(
              motion: _motion,
              playing: widget.isPlaying,
              primary: colors.primary,
              secondary: colors.secondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.motion,
    required this.playing,
    required this.primary,
    required this.secondary,
  }) : super(repaint: motion);

  final Animation<double> motion;
  final bool playing;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final int count = math.max(1, (size.width / 6).floor());
    final double step = size.width / count;
    final double phase = motion.value * math.pi * 2;
    final Paint paint = Paint()
      ..strokeWidth = math.min(3, step / 2)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final double x = (i + 0.5) * step;
      final double envelope = math.sin((i + 0.5) / count * math.pi);
      final double wave = playing
          ? 0.18 +
                0.82 *
                    (0.5 + 0.5 * math.sin(i * 0.83 + phase * 2)) *
                    (0.65 + 0.35 * math.sin(i * 0.37 - phase))
          : 0.22 + 0.42 * (0.5 + 0.5 * math.sin(i * 1.7));
      final double height = 4 + (size.height - 8) * envelope * wave;
      paint.color = Color.lerp(
        primary,
        secondary,
        i / count,
      )!.withValues(alpha: playing ? 0.85 : 0.40);
      canvas.drawLine(
        Offset(x, (size.height - height) / 2),
        Offset(x, (size.height + height) / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.motion != motion ||
      oldDelegate.playing != playing ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
