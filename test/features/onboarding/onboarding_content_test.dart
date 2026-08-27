import 'package:convertly/core/services/storage_service.dart';
import 'package:convertly/features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'package:convertly/features/onboarding/domain/entities/onboarding_slide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ships exactly the three specified onboarding slides', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final StorageService storage = await StorageService.init();
    final dataSource = OnboardingLocalDataSourceImpl(storage);

    final List<OnboardingSlide> slides = dataSource.readSlides();

    expect(slides, hasLength(3));
    expect(slides[0].title, 'Convert Videos Easily');
    expect(slides[1].title, 'Fast & Offline');
    expect(slides[2].title, 'Manage Your Media');
    expect(
      slides.map((OnboardingSlide s) => s.art),
      orderedEquals(<OnboardingArt>[
        OnboardingArt.convert,
        OnboardingArt.offline,
        OnboardingArt.manage,
      ]),
    );
  });
}
