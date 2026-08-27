import 'package:convertly/core/routes/app_routes.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/onboarding/domain/entities/onboarding_slide.dart';
import 'package:convertly/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:convertly/features/onboarding/domain/usecases/complete_onboarding.dart';
import 'package:convertly/features/onboarding/domain/usecases/get_onboarding_slides.dart';
import 'package:convertly/features/onboarding/presentation/controllers/onboarding_controller.dart';
import 'package:convertly/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

class _FakeOnboardingRepository implements OnboardingRepository {
  bool completed = false;

  @override
  Future<Result<bool>> isOnboardingCompleted() async =>
      Result<bool>.success(completed);

  @override
  Future<Result<void>> completeOnboarding() async {
    completed = true;
    return const Result<void>.success(null);
  }

  @override
  Result<List<OnboardingSlide>> getSlides() =>
      const Result<List<OnboardingSlide>>.success(<OnboardingSlide>[
        OnboardingSlide(
          title: 'Convert Videos Easily',
          description: 'Extract high-quality audio from your videos.',
          art: OnboardingArt.convert,
        ),
        OnboardingSlide(
          title: 'Fast & Offline',
          description: 'Your media stays on your device.',
          art: OnboardingArt.offline,
        ),
        OnboardingSlide(
          title: 'Manage Your Media',
          description: 'Play, rename, share and organize.',
          art: OnboardingArt.manage,
        ),
      ]);
}

void main() {
  late _FakeOnboardingRepository repository;

  setUp(() {
    repository = _FakeOnboardingRepository();
    Get.put<OnboardingController>(
      OnboardingController(
        GetOnboardingSlides(repository),
        CompleteOnboarding(repository),
      ),
    );
  });

  tearDown(Get.reset);

  Future<void> pumpOnboarding(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        initialRoute: AppRoutes.onboarding,
        getPages: <GetPage<dynamic>>[
          GetPage<void>(name: AppRoutes.onboarding, page: OnboardingPage.new),
          // Stand-in for the shell, so finishing has somewhere to navigate to.
          GetPage<void>(
            name: AppRoutes.shell,
            page: () => const Scaffold(body: Text('shell')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opens on the first slide', (WidgetTester tester) async {
    await pumpOnboarding(tester);

    expect(find.text('Convert Videos Easily'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
  });

  testWidgets('Next advances through the slides', (WidgetTester tester) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Fast & Offline'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Manage Your Media'), findsOneWidget);
  });

  testWidgets('the last slide offers Get Started and disables Skip', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);
    final OnboardingController controller = Get.find<OnboardingController>();

    controller.onPageChanged(2);
    await tester.pumpAndSettle();

    expect(find.text('Get Started'), findsOneWidget);
    expect(controller.isLastPage, isTrue);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Skip'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('finishing marks onboarding as completed', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await Get.find<OnboardingController>().finish();
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(find.text('shell'), findsOneWidget);
  });

  testWidgets('skipping also marks onboarding as completed', (
    WidgetTester tester,
  ) async {
    await pumpOnboarding(tester);

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(repository.completed, isTrue);
    expect(find.text('shell'), findsOneWidget);
  });
}
