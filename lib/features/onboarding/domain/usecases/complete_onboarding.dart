import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/onboarding_repository.dart';

/// Marks onboarding as finished so it is never shown again.
class CompleteOnboarding implements UseCase<void, NoParams> {
  const CompleteOnboarding(this._repository);

  final OnboardingRepository _repository;

  @override
  Future<Result<void>> call(NoParams params) =>
      _repository.completeOnboarding();
}
