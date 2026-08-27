import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/onboarding_slide.dart';
import '../repositories/onboarding_repository.dart';

/// Supplies the onboarding content to the presentation layer.
class GetOnboardingSlides
    implements SyncUseCase<List<OnboardingSlide>, NoParams> {
  const GetOnboardingSlides(this._repository);

  final OnboardingRepository _repository;

  @override
  Result<List<OnboardingSlide>> call(NoParams params) =>
      _repository.getSlides();
}
