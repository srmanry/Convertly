import 'package:equatable/equatable.dart';

/// Illustration to show for a slide.
///
/// Modelled as an enum rather than an icon code point for two reasons: the
/// domain layer stays free of Flutter types, and the presentation layer can map
/// it to a *const* `IconData`, which keeps `--tree-shake-icons` working in
/// release builds.
enum OnboardingArt { convert, offline, manage }

/// One page of the onboarding carousel.
class OnboardingSlide extends Equatable {
  const OnboardingSlide({
    required this.title,
    required this.description,
    required this.art,
  });

  final String title;
  final String description;
  final OnboardingArt art;

  @override
  List<Object?> get props => <Object?>[title, description, art];
}
