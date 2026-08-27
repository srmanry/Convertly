import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';

/// A titled group of settings rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimens.spaceXs,
            AppDimens.spaceXl,
            AppDimens.spaceXs,
            AppDimens.spaceSm,
          ),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: colors.primary,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Card(
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i++) ...<Widget>[
                if (i > 0)
                  const Divider(
                    indent: AppDimens.spaceLg,
                    endIndent: AppDimens.spaceLg,
                  ),
                children[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
