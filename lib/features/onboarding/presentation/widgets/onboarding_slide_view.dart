import 'package:flutter/material.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../domain/entities/onboarding_slide.dart';

class OnboardingSlideView extends StatelessWidget {
  const OnboardingSlideView({required this.slide, super.key});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimens.pagePadding),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _iconFor(slide.art),
              size: 76,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppDimens.spaceXxl + AppDimens.spaceSm),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppDimens.spaceMd),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Const mapping keeps the icon font tree-shakeable in release builds.
  IconData _iconFor(OnboardingArt art) => switch (art) {
    OnboardingArt.convert => Icons.movie_filter_rounded,
    OnboardingArt.offline => Icons.offline_bolt_rounded,
    OnboardingArt.manage => Icons.library_music_rounded,
  };
}
