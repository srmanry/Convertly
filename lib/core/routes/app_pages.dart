import 'package:get/get.dart';

import '../../features/audio_player/presentation/bindings/audio_player_binding.dart';
import '../../features/audio_player/presentation/pages/audio_player_page.dart';
import '../../features/converter/presentation/bindings/converter_binding.dart';
import '../../features/converter/presentation/pages/conversion_result_page.dart';
import '../../features/converter/presentation/pages/converter_page.dart';
import '../../features/onboarding/presentation/bindings/onboarding_binding.dart';
import '../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import '../../features/shell/presentation/bindings/shell_binding.dart';
import '../../features/shell/presentation/pages/shell_page.dart';
import '../../features/splash/presentation/bindings/splash_binding.dart';
import '../../features/splash/presentation/pages/splash_page.dart';
import 'app_routes.dart';

/// Central route table. Adding a screen means adding one entry here.
abstract final class AppPages {
  static const String initial = AppRoutes.splash;

  static final List<GetPage<dynamic>> pages = <GetPage<dynamic>>[
    GetPage<void>(
      name: AppRoutes.splash,
      page: SplashPage.new,
      binding: SplashBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.onboarding,
      page: OnboardingPage.new,
      binding: OnboardingBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.shell,
      page: ShellPage.new,
      binding: ShellBinding(),
      transition: Transition.fadeIn,
    ),
    GetPage<void>(
      name: AppRoutes.converter,
      page: ConverterPage.new,
      binding: ConverterBinding(),
    ),
    GetPage<void>(
      name: AppRoutes.conversionResult,
      page: ConversionResultPage.new,
    ),
    GetPage<void>(
      name: AppRoutes.audioPlayer,
      page: AudioPlayerPage.new,
      binding: AudioPlayerBinding(),
    ),
    GetPage<void>(name: AppRoutes.settings, page: SettingsPage.new),
  ];
}
