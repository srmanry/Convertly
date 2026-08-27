import 'package:get/get.dart';

import '../../../../core/services/storage_service.dart';
import '../../data/datasources/onboarding_local_datasource.dart';
import '../../data/repositories/onboarding_repository_impl.dart';
import '../../domain/repositories/onboarding_repository.dart';
import '../../domain/usecases/complete_onboarding.dart';
import '../../domain/usecases/get_onboarding_slides.dart';
import '../controllers/onboarding_controller.dart';

/// Wires the onboarding dependency graph when the route is opened.
class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    final OnboardingRepository repository = OnboardingRepositoryImpl(
      OnboardingLocalDataSourceImpl(Get.find<StorageService>()),
    );

    Get.lazyPut<OnboardingController>(
      () => OnboardingController(
        GetOnboardingSlides(repository),
        CompleteOnboarding(repository),
      ),
    );
  }
}
