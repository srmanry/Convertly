import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/onboarding_slide.dart';

/// Local persistence and static content for onboarding.
abstract interface class OnboardingLocalDataSource {
  bool readCompleted();

  Future<void> writeCompleted();

  List<OnboardingSlide> readSlides();
}

class OnboardingLocalDataSourceImpl implements OnboardingLocalDataSource {
  const OnboardingLocalDataSourceImpl(this._storage);

  final StorageService _storage;

  @override
  bool readCompleted() =>
      _storage.readBool(StorageKeys.onboardingCompleted) ?? false;

  @override
  Future<void> writeCompleted() =>
      _storage.writeBool(StorageKeys.onboardingCompleted, true);

  @override
  List<OnboardingSlide> readSlides() => const <OnboardingSlide>[
    OnboardingSlide(
      title: 'Convert Videos Easily',
      description:
          'Extract high-quality audio from your videos in just a few taps.',
      art: OnboardingArt.convert,
    ),
    OnboardingSlide(
      title: 'Fast & Offline',
      description: 'Your media stays on your device. No cloud upload required.',
      art: OnboardingArt.offline,
    ),
    OnboardingSlide(
      title: 'Manage Your Media',
      description: 'Play, rename, share and organize your converted files.',
      art: OnboardingArt.manage,
    ),
  ];
}
