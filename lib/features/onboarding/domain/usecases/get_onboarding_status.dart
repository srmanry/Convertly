import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/onboarding_repository.dart';

/// Reads whether onboarding was already completed. Drives splash routing.
class GetOnboardingStatus implements UseCase<bool, NoParams> {
  const GetOnboardingStatus(this._repository);

  final OnboardingRepository _repository;

  @override
  Future<Result<bool>> call(NoParams params) =>
      _repository.isOnboardingCompleted();
}
