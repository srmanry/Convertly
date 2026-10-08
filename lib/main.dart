import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/startup.dart';
import 'core/i18n/app_translations.dart';
import 'core/routes/app_pages.dart';
import 'core/services/ads_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/types/result.dart';
import 'core/usecases/usecase.dart';
import 'features/onboarding/data/datasources/onboarding_local_datasource.dart';
import 'features/onboarding/data/repositories/onboarding_repository_impl.dart';
import 'features/onboarding/domain/usecases/get_onboarding_status.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Storage is resolved before the first frame so the saved theme applies
  // immediately, with no flash of the wrong brightness.
  final StorageService storage = await StorageService.init();
  InitialBinding(storage).dependencies();
  await Get.find<SettingsController>().load();

  // Not awaited: the SDK reaches out to the network, and the app must not
  // wait on that to draw its first screen. Ads appear once it is ready.
  unawaited(Get.find<AdsService>().initialise());

  // Read here rather than on a splash screen of its own. It is one value out
  // of storage that is already open, so the first screen the user sees can be
  // the real one. A failed read falls back to onboarding, which is harmless.
  final Result<bool> onboarding =
      await GetOnboardingStatus(
        OnboardingRepositoryImpl(OnboardingLocalDataSourceImpl(storage)),
      )(const NoParams());

  runApp(
    AudioForgeApp(
      initialRoute: startRoute(
        onboardingCompleted: onboarding.valueOrNull ?? false,
      ),
    ),
  );
}

class AudioForgeApp extends StatelessWidget {
  const AudioForgeApp({required this.initialRoute, super.key});

  /// The first screen, worked out in [main] before this is built.
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      // The app ships dark-only: no light or system option is offered,
      // so this is fixed rather than read from settings.
      themeMode: ThemeMode.dark,
      // Text, and the date and layout conventions that go with it: Arabic
      // lays the whole interface out right to left, which the delegates below
      // handle once the locale says so.
      translations: AppTranslations(),
      locale: AppTranslations.resolveLocale(
        Get.find<SettingsController>().settings.value.languageCode,
        Get.deviceLocale,
      ),
      fallbackLocale: AppTranslations.fallbackLocale,
      supportedLocales: AppTranslations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: initialRoute,
      getPages: AppPages.pages,
      // A slide, not a fade or a zoom: those draw the arriving screen
      // half-transparent while it settles, and two of these backdrops seen
      // through each other look smeared. This one keeps the new screen solid
      // and moves it over the old, and it brings the swipe-back gesture with
      // it. Transition.native is no use here: GetX builds that from the
      // framework's default theme, not the app's.
      defaultTransition: Transition.cupertino,
    );
  }
}
