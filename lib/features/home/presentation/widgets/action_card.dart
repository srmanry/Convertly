import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../../../core/widgets/depth_surface.dart';

/// Large primary action card used for the main converter entry points.
class ActionCard extends StatelessWidget {
  const ActionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accentColor,
    super.key,
    this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accentColor;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return DepthSurface(
      onTap: onTap,
      tint: accentColor,
      elevation: 1.15,
      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
      padding: const EdgeInsets.all(AppDimens.spaceLg),
      child: Row(
        children: <Widget>[
          DepthChip(
            icon: icon,
            color: accentColor,
            size: 52,
            iconSize: AppDimens.iconLg - 6,
          ),
          const SizedBox(width: AppDimens.spaceLg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    if (badge != null) ...<Widget>[
                      const SizedBox(width: AppDimens.spaceSm),
                      _Badge(label: badge!),
                    ],
                  ],
                ),
                const SizedBox(height: AppDimens.spaceXs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: accentColor.withValues(alpha: 0.18)),
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: AppDimens.iconSm,
              color: accentColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(AppDimens.radiusSm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
