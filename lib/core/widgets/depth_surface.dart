import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_depth.dart';

/// A raised, tappable surface that behaves like a physical object.
///
/// Three things together sell the depth, and dropping any one of them flattens
/// the rest: a layered shadow that puts the surface above the background, a lit
/// top edge that agrees with [AppDepth.lightSource], and a press that tips the
/// surface toward the finger instead of merely dimming it.
///
/// The tilt is a real perspective transform, not a fake skew, so the far edge
/// genuinely foreshortens — that is what stops it reading as a sliding image.
class DepthSurface extends StatefulWidget {
  const DepthSurface({
    required this.child,
    required this.borderRadius,
    super.key,
    this.onTap,
    this.color,
    this.tint,
    this.elevation = 1,
    this.tilt = true,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  /// Face colour. Defaults to the theme's low container.
  final Color? color;

  /// Accent that bleeds into the drop shadow and the lit edge, so a card's
  /// colour reads as light bouncing off it rather than as a border.
  final Color? tint;

  /// How high the surface sits. Scales every shadow in the stack together.
  final double elevation;

  /// Whether pressing tips the surface toward the touch point.
  final bool tilt;

  final EdgeInsetsGeometry padding;

  @override
  State<DepthSurface> createState() => _DepthSurfaceState();
}

class _DepthSurfaceState extends State<DepthSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: AppDepth.pressDuration,
    reverseDuration: AppDepth.releaseDuration,
  );

  /// Where the finger landed, in -1..1 across the surface. Drives which way
  /// the card tips: press the right edge and the right edge goes down.
  Offset _anchor = Offset.zero;

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      final Size size = box.size;
      _anchor = Offset(
        (details.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (details.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    }
    _press.forward();
  }

  void _release() => _press.reverse();

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final ColorScheme colors = theme.colorScheme;
    final Color face = widget.color ?? colors.surfaceContainerLow;
    final bool interactive = widget.onTap != null;

    final Widget surface = AnimatedBuilder(
      animation: _press,
      builder: (BuildContext context, Widget? child) {
        // Ease-out on the way down, so contact feels immediate and the
        // release floats back up.
        final double t = Curves.easeOutCubic.transform(_press.value);
        final double lift = widget.elevation * (1 - 0.62 * t);

        final Matrix4 transform = Matrix4.identity()
          ..setEntry(3, 2, AppDepth.perspective);
        if (widget.tilt) {
          transform
            ..rotateX(_anchor.dy * AppDepth.tiltRadians * t)
            ..rotateY(-_anchor.dx * AppDepth.tiltRadians * t);
        }
        final double shrink = 1 - (1 - AppDepth.pressedScale) * t;
        transform.scaleByDouble(shrink, shrink, 1, 1);

        return Transform(
          alignment: Alignment.center,
          transform: transform,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: face,
              borderRadius: widget.borderRadius,
              boxShadow: AppDepth.lift(
                isDark: isDark,
                elevation: math.max(lift, 0),
                tint: widget.tint,
              ),
            ),
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: Stack(
          children: <Widget>[
            Padding(padding: widget.padding, child: widget.child),
            // Face shading, painted over the content so the whole card — text
            // included — sits under the same light.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppDepth.face(isDark: isDark, tint: widget.tint),
                  ),
                ),
              ),
            ),
            // The lit top edge. Fades out at the corners, where the surface
            // curves away from the light.
            Positioned(
              top: 0,
              left: widget.borderRadius.topLeft.x,
              right: widget.borderRadius.topRight.x,
              child: IgnorePointer(
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        Colors.transparent,
                        AppDepth.rim(isDark),
                        Colors.transparent,
                      ],
                      stops: const <double>[0, 0.35, 1],
                    ),
                  ),
                ),
              ),
            ),
            if (interactive)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: InkWell(
                    onTap: widget.onTap,
                    onTapDown: _onTapDown,
                    onTapUp: (_) => _release(),
                    onTapCancel: _release,
                    splashColor: (widget.tint ?? colors.primary).withValues(
                      alpha: 0.1,
                    ),
                    highlightColor: Colors.transparent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    return surface;
  }
}

/// A softly tinted icon chip used on raised surfaces.
///
/// The accent stays on the icon and edge instead of flooding the whole tile.
/// This keeps bright palette colours crisp without turning every icon into a
/// glossy block of neon.
class DepthChip extends StatelessWidget {
  const DepthChip({
    required this.icon,
    required this.color,
    required this.size,
    super.key,
    this.iconSize,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final BorderRadius radius = BorderRadius.circular(size * 0.32);
    final Color chipColor = Color.alphaBlend(
      color.withValues(alpha: isDark ? 0.16 : 0.1),
      theme.colorScheme.surfaceContainerHighest,
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: radius,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.46 : 0.34),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: color.withValues(alpha: isDark ? 0.2 : 0.12),
            blurRadius: size * 0.36,
            spreadRadius: -size * 0.14,
            offset: Offset(0, size * 0.1),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.24 : 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: size * 0.1,
            left: size * 0.12,
            child: Container(
              width: size * 0.16,
              height: size * 0.16,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.5),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Icon(
            icon,
            size: iconSize ?? size * 0.5,
            color: isDark ? Color.lerp(color, Colors.white, 0.16) : color,
            shadows: <Shadow>[
              Shadow(
                color: color.withValues(alpha: isDark ? 0.42 : 0.18),
                blurRadius: 8,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
