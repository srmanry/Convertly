import 'package:get/get.dart';

import '../../../../core/services/storage_service.dart';
import '../../../onboarding/data/datasources/onboarding_local_datasource.dart';
import '../../../onboarding/data/repositories/onboarding_repository_impl.dart';
import '../../../onboarding/domain/repositories/onboarding_repository.dart';
import '../../../onboarding/domain/usecases/get_onboarding_status.dart';
import '../controllers/splash_controller.dart';

class SplashBinding extends Bindings {
  @override
  void dependencies() {
    final OnboardingRepository repository = OnboardingRepositoryImpl(
      OnboardingLocalDataSourceImpl(Get.find<StorageService>()),
    );

    // Instantiated eagerly, not lazily: SplashPage never calls Get.find, so a
    // lazy registration would never be constructed and the controller's
    // onReady - which resolves the start destination - would never run.
    Get.put<SplashController>(
      SplashController(GetOnboardingStatus(repository)),
    );
  }
}
