import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/constants/app_dimens.dart';
import '../../domain/entities/onboarding_slide.dart';
import '../controllers/onboarding_controller.dart';
import '../widgets/onboarding_slide_view.dart';
import '../widgets/page_dots_indicator.dart';

class OnboardingPage extends GetView<OnboardingController> {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppDimens.maxContentWidth,
            ),
            child: Column(
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: Obx(
                    () => TextButton(
                      onPressed: controller.isLastPage ? null : controller.skip,
                      child: const Text('Skip'),
                    ),
                  ),
                ),
                Expanded(
                  child: Obx(
                    () => PageView.builder(
                      controller: controller.pageController,
                      onPageChanged: controller.onPageChanged,
                      itemCount: controller.slides.length,
                      itemBuilder: (BuildContext context, int index) {
                        final OnboardingSlide slide = controller.slides[index];
                        return OnboardingSlideView(slide: slide);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXl),
                Obx(
                  () => PageDotsIndicator(
                    count: controller.slides.length,
                    currentIndex: controller.currentIndex.value,
                  ),
                ),
                const SizedBox(height: AppDimens.spaceXl),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimens.pagePadding,
                    0,
                    AppDimens.pagePadding,
                    AppDimens.spaceXl,
                  ),
                  child: Obx(
                    () => FilledButton(
                      onPressed: controller.isFinishing.value
                          ? null
                          : controller.next,
                      child: Text(
                        controller.isLastPage ? 'Get Started' : 'Next',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
