import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../../../core/types/result.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../datasources/onboarding_local_datasource.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  const OnboardingRepositoryImpl(this._localDataSource);

  final OnboardingLocalDataSource _localDataSource;

  @override
  Future<Result<bool>> isOnboardingCompleted() async {
    try {
      return Result<bool>.success(_localDataSource.readCompleted());
    } on CacheException catch (error) {
      return Result<bool>.failure(CacheFailure(debugMessage: error.toString()));
    } catch (error) {
      // A missing flag must never block the app; fall back to showing onboarding.
      return Result<bool>.failure(
        UnknownFailure(debugMessage: error.toString()),
      );
    }
  }

  @override
  Future<Result<void>> completeOnboarding() async {
    try {
      await _localDataSource.writeCompleted();
      return const Result<void>.success(null);
    } on CacheException catch (error) {
      return Result<void>.failure(
        CacheFailure(
          message: 'Could not save your progress. Please try again.',
          debugMessage: error.toString(),
        ),
      );
    } catch (error) {
      return Result<void>.failure(
        UnknownFailure(debugMessage: error.toString()),
      );
    }
  }

  @override
  Result<List<OnboardingSlide>> getSlides() {
    return Result<List<OnboardingSlide>>.success(_localDataSource.readSlides());
  }
}
