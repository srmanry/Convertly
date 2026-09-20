import 'package:get/get.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/storage_service.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../../../../core/i18n/translation_keys.dart';

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
  // Read each time rather than held in a const list: the slides are words,
  // and the language they are read in can change.
  List<OnboardingSlide> readSlides() => <OnboardingSlide>[
    OnboardingSlide(
      title: K.onboardingConvertTitle.tr,
      description: K.onboardingConvertBody.tr,
      art: OnboardingArt.convert,
    ),
    OnboardingSlide(
      title: K.onboardingOfflineTitle.tr,
      description: K.onboardingOfflineBody.tr,
      art: OnboardingArt.offline,
    ),
    OnboardingSlide(
      title: K.onboardingManageTitle.tr,
      description: K.onboardingManageBody.tr,
      art: OnboardingArt.manage,
    ),
  ];
}
