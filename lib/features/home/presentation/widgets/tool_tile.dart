import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';

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

  static const double _iconBoxSize = 44;

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

    return AppDimens.spaceLg * 2 +
        _iconBoxSize +
        AppDimens.spaceMd +
        labelHeight;
  }

  final IconData icon;
  final String label;
  final Color accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimens.spaceMd,
            vertical: AppDimens.spaceLg,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: _iconBoxSize,
                height: _iconBoxSize,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                ),
                child: Icon(icon, color: accentColor, size: AppDimens.iconMd),
              ),
              const SizedBox(height: AppDimens.spaceMd),
              // Flexible plus ellipsis is the last-resort guard: an unusually
              // long label shortens instead of overflowing the tile.
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: _labelLines,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
