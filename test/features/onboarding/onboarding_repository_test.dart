import 'package:convertly/core/errors/exceptions.dart';
import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:convertly/features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'package:convertly/features/onboarding/domain/entities/onboarding_slide.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOnboardingLocalDataSource implements OnboardingLocalDataSource {
  _FakeOnboardingLocalDataSource({
    this.completed = false,
    this.throwOnWrite = false,
  });

  bool completed;
  bool throwOnWrite;
  int writeCount = 0;

  @override
  bool readCompleted() => completed;

  @override
  Future<void> writeCompleted() async {
    writeCount++;
    if (throwOnWrite) {
      throw const CacheException('disk full');
    }
    completed = true;
  }

  @override
  List<OnboardingSlide> readSlides() => const <OnboardingSlide>[
    OnboardingSlide(title: 'a', description: 'b', art: OnboardingArt.convert),
  ];
}

void main() {
  group('OnboardingRepositoryImpl', () {
    test('reports the stored completion flag', () async {
      final repository = OnboardingRepositoryImpl(
        _FakeOnboardingLocalDataSource(completed: true),
      );

      expect((await repository.isOnboardingCompleted()).valueOrNull, isTrue);
    });

    test('defaults to not completed on a first run', () async {
      final repository = OnboardingRepositoryImpl(
        _FakeOnboardingLocalDataSource(),
      );

      expect((await repository.isOnboardingCompleted()).valueOrNull, isFalse);
    });

    test('persists completion', () async {
      final dataSource = _FakeOnboardingLocalDataSource();
      final repository = OnboardingRepositoryImpl(dataSource);

      final Result<void> result = await repository.completeOnboarding();

      expect(result.isSuccess, isTrue);
      expect(dataSource.completed, isTrue);
    });

    test('maps a write failure to a user-safe CacheFailure', () async {
      final repository = OnboardingRepositoryImpl(
        _FakeOnboardingLocalDataSource(throwOnWrite: true),
      );

      final Result<void> result = await repository.completeOnboarding();
      final Failure? failure = result.failureOrNull;

      expect(failure, isA<CacheFailure>());
      expect(failure!.message, isNot(contains('disk full')));
      expect(failure.debugMessage, contains('disk full'));
    });

    test('returns the onboarding slides', () {
      final repository = OnboardingRepositoryImpl(
        _FakeOnboardingLocalDataSource(),
      );

      expect(repository.getSlides().valueOrNull, hasLength(1));
    });
  });
}
