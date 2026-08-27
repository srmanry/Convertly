import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../../core/routes/app_routes.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../../domain/usecases/complete_onboarding.dart';
import '../../domain/usecases/get_onboarding_slides.dart';

/// Drives the onboarding carousel. Holds no business rules of its own; it only
/// coordinates use cases and view state.
class OnboardingController extends GetxController {
  OnboardingController(this._getSlides, this._completeOnboarding);

  final GetOnboardingSlides _getSlides;
  final CompleteOnboarding _completeOnboarding;

  final PageController pageController = PageController();

  final RxList<OnboardingSlide> slides = <OnboardingSlide>[].obs;
  final RxInt currentIndex = 0.obs;
  final RxBool isFinishing = false.obs;

  bool get isLastPage =>
      slides.isNotEmpty && currentIndex.value == slides.length - 1;

  @override
  void onInit() {
    super.onInit();
    slides.assignAll(
      _getSlides(const NoParams()).valueOrNull ?? const <OnboardingSlide>[],
    );
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }

  void onPageChanged(int index) => currentIndex.value = index;

  void next() {
    if (isLastPage) {
      finish();
      return;
    }
    pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void skip() => finish();

  /// Persists completion and moves on. Navigation happens even if persistence
  /// fails, so a storage error can never trap the user on onboarding.
  Future<void> finish() async {
    if (isFinishing.value) {
      return;
    }
    isFinishing.value = true;
    await _completeOnboarding(const NoParams());
    isFinishing.value = false;

    // Not awaited: GetX completes this future only when the destination route
    // is itself popped, so awaiting it would never return.
    unawaited(Get.offAllNamed<void>(AppRoutes.shell));
  }
}
