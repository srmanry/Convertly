import 'package:flutter/material.dart';

import '../constants/app_dimens.dart';

/// The same AudioForge mark used by the launcher and native splash.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: Image.asset(
        'assets/logo/audio.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
        excludeFromSemantics: true,
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
