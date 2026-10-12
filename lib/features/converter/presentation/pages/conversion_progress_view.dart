import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/banner_ad_view.dart';
import '../../domain/entities/media_info.dart';
import '../controllers/converter_controller.dart';

/// Progress state of an in-flight conversion, with a cancel action.
class ConversionProgressView extends GetView<ConverterController> {
  const ConversionProgressView({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimens.pagePadding),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(
                0,
                constraints.maxHeight - AppDimens.pagePadding * 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Column(
                  children: <Widget>[
                    const SizedBox(height: AppDimens.spaceXl),
                    Obx(
                      () => _ProgressOrb(progress: controller.progress.value),
                    ),
                    const SizedBox(height: AppDimens.spaceXl),
                    Text(
                      K.converting.trParams(<String, String>{
                        'tool': controller.mode.title.toLowerCase(),
                      }),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceSm),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        K.keepAppOpen.tr,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimens.spaceXxl),
                    Obx(() {
                      final MediaInfo? source = controller.primarySource;
                      return source == null
                          ? const SizedBox.shrink()
                          : _ProcessingFileCard(source: source);
                    }),
                    const SizedBox(height: AppDimens.spaceXl),
                    OutlinedButton.icon(
                      onPressed: controller.cancel,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colors.onSurfaceVariant,
                        backgroundColor: colors.surface.withValues(alpha: 0.2),
                        side: BorderSide(
                          color: colors.outlineVariant.withValues(alpha: 0.6),
                        ),
                        minimumSize: const Size.fromHeight(
                          AppDimens.buttonHeight,
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(K.cancel.tr),
                    ),
                  ],
                ),
                // Only reserve space once an ad loads. The bottom placement
                // keeps it well away from the cancel action, including when
                // large text or a short display makes the content scroll.
                BannerAdView(
                  width:
                      constraints.maxWidth.floor() -
                      AppDimens.pagePadding.toInt() * 2,
                  padding: const EdgeInsets.only(top: 48),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ProcessingFileCard extends StatelessWidget {
  const _ProcessingFileCard({required this.source});

  final MediaInfo source;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final String metadata = <String>[
      if (source.extension.isNotEmpty) source.extension.toUpperCase(),
      Formatters.fileSize(source.sizeInBytes),
      if (source.duration != null) Formatters.duration(source.duration!),
    ].join('  ·  ');

    return Container(
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            ),
            child: Icon(
              source.hasVideo
                  ? Icons.video_file_rounded
                  : Icons.audio_file_rounded,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppDimens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  source.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  metadata,
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressOrb extends StatefulWidget {
  const _ProgressOrb({required this.progress});

  final double progress;

  @override
  State<_ProgressOrb> createState() => _ProgressOrbState();
}

class _ProgressOrbState extends State<_ProgressOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
    } else {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final double progress = widget.progress.clamp(0.0, 1.0);
    final bool reducedMotion = MediaQuery.disableAnimationsOf(context);
    final String label = progress > 0 ? '${(progress * 100).round()}%' : '…';

    return Semantics(
      value: progress > 0 ? label : null,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 184,
          height: 184,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      colors.primary.withValues(alpha: 0.17),
                      colors.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Container(
                width: 136,
                height: 136,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      colors.primary.withValues(alpha: 0.08),
                      colors.surface.withValues(alpha: 0.35),
                    ],
                  ),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.12),
                  ),
                ),
              ),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: reducedMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double value, Widget? child) {
                  return AnimatedBuilder(
                    animation: _pulse,
                    builder: (BuildContext context, Widget? child) {
                      return CustomPaint(
                        size: const Size.square(164),
                        painter: _ProgressRingPainter(
                          progress: progress > 0 ? value : null,
                          phase: _pulse.value,
                          primary: colors.primary,
                          secondary: colors.secondary,
                        ),
                      );
                    },
                  );
                },
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (BuildContext context, Widget? child) {
                      return SizedBox(
                        height: 24,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: List<Widget>.generate(7, (int index) {
                            final double wave = math.sin(
                              _pulse.value * math.pi * 2 + index * 0.8,
                            );
                            return Container(
                              width: 4,
                              height: 8 + (wave + 1) * 8,
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  colors.primary,
                                  colors.secondary,
                                  index / 6,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppDimens.spaceSm),
                  Text(
                    label,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                      color: colors.onSurface,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.progress,
    required this.phase,
    required this.primary,
    required this.secondary,
  });

  final double? progress;
  final double phase;
  final Color primary;
  final Color secondary;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2 - 10;
    final Rect bounds = Rect.fromCircle(center: center, radius: radius);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..color = primary.withValues(alpha: 0.12);
    canvas.drawCircle(center, radius, track);

    final double start =
        -math.pi / 2 + (progress == null ? phase * math.pi * 2 : 0);
    final double sweep = (progress ?? 0.24) * math.pi * 2;
    final Paint arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        transform: GradientRotation(start),
        colors: <Color>[secondary, primary, primary],
        stops: <double>[0, (sweep / (math.pi * 2)).clamp(0.001, 1), 1],
      ).createShader(bounds);
    canvas.drawArc(bounds, start, sweep, false, arc);

    final Offset tip =
        center +
        Offset(
          math.cos(start + sweep) * radius,
          math.sin(start + sweep) * radius,
        );
    canvas.drawCircle(
      tip,
      9,
      Paint()
        ..color = primary.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(tip, 4, Paint()..color = primary);
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.phase != phase ||
      oldDelegate.primary != primary ||
      oldDelegate.secondary != secondary;
}
