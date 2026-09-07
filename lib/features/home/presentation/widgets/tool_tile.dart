import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/depth_surface.dart';

/// Compact square tile used in the Tools grid.
class ToolTile extends StatelessWidget {
  const ToolTile({
    required this.icon,
    required this.label,
    required this.accentColor,
    super.key,
    this.onTap,
  });

  /// Longest label the grid must accommodate without clipping.
  static const int _labelLines = 2;

  static const double _iconBoxSize = 42;

  /// Height a tile needs for an icon plus a [_labelLines]-line label.
  ///
  /// The grid sizes rows with this rather than an aspect ratio, so tile height
  /// no longer depends on screen width and scales with the user's font size.
  static double heightFor(BuildContext context) {
    final TextStyle? labelStyle = Theme.of(context).textTheme.labelLarge;
    final double fontSize = labelStyle?.fontSize ?? 14;
    final double lineHeight = fontSize * (labelStyle?.height ?? 1.3);
    final double labelHeight =
        MediaQuery.textScalerOf(context).scale(lineHeight) * _labelLines;

    return AppDimens.spaceMd * 2 +
        _iconBoxSize +
        AppDimens.spaceMd +
        labelHeight +
        AppDimens.spaceSm +
        3;
  }

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DepthSurface(
      onTap: onTap,
      tint: accentColor,
      elevation: 0.82,
      borderRadius: BorderRadius.circular(AppDimens.radiusXl - 4),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimens.spaceMd,
        vertical: AppDimens.spaceMd,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned(
            top: -36,
            right: -30,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.055),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              DepthChip(
                icon: icon,
                color: accentColor,
                size: _iconBoxSize,
                iconSize: AppDimens.iconMd - 2,
              ),
              const SizedBox(height: AppDimens.spaceMd),
              // Every label owns the same flexible area. A one-line label no
              // longer shortens and re-centres the whole column, so all icon
              // chips and bottom accents stay on the same horizontal lines.
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: _labelLines,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimens.spaceSm),
              Container(
                width: 22,
                height: 3,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.28),
                      blurRadius: 7,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
