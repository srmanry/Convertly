import 'package:flutter/material.dart';

import '../constants/app_dimens.dart';
import '../theme/app_colors.dart';

/// The Convertly mark: a rounded gradient tile with a waveform glyph.
///
/// Drawn rather than loaded from an asset so it stays crisp at any size and
/// adds no binary weight before the real icon set lands in the release phase.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.brandGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.seed.withValues(alpha: 0.32),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Icon(
        Icons.graphic_eq_rounded,
        size: size * 0.5,
        color: Colors.white,
      ),
    );
  }
}

/// Compact logo plus wordmark, used in app bars and the home header.
class AppLogoTitle extends StatelessWidget {
  const AppLogoTitle({super.key, this.title, this.logoSize = 32});

  final String? title;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AppLogo(size: logoSize),
        if (title != null) ...<Widget>[
          const SizedBox(width: AppDimens.spaceMd),
          Text(title!, style: Theme.of(context).textTheme.titleLarge),
        ],
      ],
    );
  }
}
