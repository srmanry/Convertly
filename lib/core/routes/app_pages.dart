import 'package:get/get.dart';

import '../../features/audio_player/presentation/bindings/audio_player_binding.dart';
import '../../features/audio_player/presentation/pages/audio_player_page.dart';
import '../../features/converter/presentation/bindings/converter_binding.dart';
import '../../features/converter/presentation/pages/conversion_result_page.dart';
import '../../features/converter/presentation/pages/converter_page.dart';
import '../../features/onboarding/presentation/bindings/onboarding_binding.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/settings/presentation/bindings/storage_binding.dart';
import '../../features/settings/presentation/pages/privacy_policy_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/settings/presentation/pages/storage_page.dart';
import '../../features/shell/presentation/bindings/shell_binding.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/splash/presentation/bindings/splash_binding.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import '../widgets/neon_backdrop.dart';
import 'app_routes.dart';

/// Central route table. Adding a screen means adding one entry here.
abstract final class AppPages {
  static const String initial = AppRoutes.splash;

  /// Gives a page its own copy of the app background.
  ///
  /// Scaffolds are transparent so the gradient shows through them. A page
  /// that paints nothing, though, is see-through during a route animation:
  /// the screen being left shows straight through the one arriving, which
  /// makes every push and pop look smeared. Its own backdrop makes it solid.
  static GetPageBuilder _opaque(GetPageBuilder builder) =>
      () => NeonBackdrop(child: builder());

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<void>(
      name: AppRoutes.splash,
      page: _opaque(SplashPage.new),
      binding: SplashBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.onboarding,
      page: _opaque(OnboardingPage.new),
      binding: OnboardingBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.shell,
      page: _opaque(ShellPage.new),
      binding: ShellBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.converter,
      page: _opaque(ConverterPage.new),
      binding: ConverterBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.conversionResult,
      page: _opaque(ConversionResultPage.new),
    ),
    GetPage<void>(
      name: AppRoutes.audioPlayer,
      page: _opaque(AudioPlayerPage.new),
      binding: AudioPlayerBinding(),
    ),
    GetPage<void>(name: AppRoutes.settings, page: _opaque(SettingsPage.new)),
    GetPage<void>(
      name: AppRoutes.privacyPolicy,
      page: _opaque(PrivacyPolicyPage.new),
    ),
    GetPage<void>(
      name: AppRoutes.storage,
      page: _opaque(StoragePage.new),
      binding: StorageBinding(),
    ),
  ];
}
