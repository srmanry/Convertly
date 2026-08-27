import '../../../../core/types/result.dart';
import '../entities/onboarding_slide.dart';

/// Contract the domain layer depends on; implemented in the data layer.
abstract interface class OnboardingRepository {
  /// Whether the user has already finished onboarding on this device.
  Future<Result<bool>> isOnboardingCompleted();

  /// Records that onboarding has been finished or skipped.
  Future<Result<void>> completeOnboarding();

  /// The slides to display, in order.
  Result<List<OnboardingSlide>> getSlides();
}
