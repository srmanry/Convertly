import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/i18n/app_translations.dart';
import 'core/routes/app_pages.dart';
import 'core/services/ads_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
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

  runApp(const AudioForgeApp());
}

class AudioForgeApp extends StatelessWidget {
  const AudioForgeApp({super.key});

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
      initialRoute: AppPages.initial,
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
