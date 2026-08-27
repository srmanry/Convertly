import 'dart:async';

import 'package:get/get.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/routes/app_routes.dart';
import '../../../../core/types/result.dart';
import '../../../../core/usecases/usecase.dart';
import '../../../onboarding/domain/usecases/get_onboarding_status.dart';

/// Decides where the app starts: onboarding for a first run, otherwise the
/// main shell.
class SplashController extends GetxController {
  SplashController(this._getOnboardingStatus);

  final GetOnboardingStatus _getOnboardingStatus;

  @override
  void onReady() {
    super.onReady();
    _resolveStartDestination();
  }

  Future<void> _resolveStartDestination() async {
    final Future<Result<bool>> statusFuture = _getOnboardingStatus(
      const NoParams(),
    );
    // Held together with a minimum delay so branding shows for a predictable
    // time regardless of how fast storage responds.
    final Future<void> minimumDelay = Future<void>.delayed(
      AppConstants.splashDuration,
    );

    final Result<bool> status = await statusFuture;
    await minimumDelay;

    // A failed read falls back to onboarding, which is harmless.
    final bool completed = status.valueOrNull ?? false;

    // Not awaited: GetX completes this future only when the destination route
    // is itself popped, so awaiting it would never return.
    unawaited(
      Get.offAllNamed<void>(completed ? AppRoutes.shell : AppRoutes.onboarding),
    );
  }
}
