import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/i18n/app_translations.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/services/ads_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/app_startup.dart';
import 'features/settings/presentation/controllers/settings_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Started here rather than inside the initializer, so the wait for storage
  // overlaps building the first frame instead of beginning after it. This is
  // the longest single step in startup: it is the first call across to the
  // platform, which is what pays for loading every plugin's native code.
  //
  // The error is caught so a failure here is not an unhandled one before the
  // app is even built; the initializer below sees it and asks again.
  final Future<StorageService?> storage = StorageService.init().then(
    (StorageService value) => value,
    onError: (Object _) => null,
  );

  AppTranslations.install(
    locale: AppTranslations.resolveLocale(null, Get.deviceLocale),
  );
  // Draw immediately; disk access must not hold the native splash open.
  runApp(
    AppStartup(
      initialize: () => _initializeApp(storage),
      ready: const AudioForgeApp(),
    ),
  );
}

Future<void> _initializeApp(Future<StorageService?> pending) async {
  // A second attempt starts its own: the head start above is used once, and
  // retrying must not hand back the same failure for ever.
  final StorageService storage = await pending ?? await StorageService.init();
  InitialBinding(storage).dependencies();
  await Get.find<SettingsController>().load();
}

class AudioForgeApp extends StatefulWidget {
  const AudioForgeApp({super.key});

  @override
  State<AudioForgeApp> createState() => _AudioForgeAppState();
}

class _AudioForgeAppState extends State<AudioForgeApp> {
  @override
  void initState() {
    super.initState();
    // Consent and advertising start only after the home screen has drawn.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(Get.find<AdsService>().initialise());
      }
    });
  }

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
      initialRoute: AppRoutes.shell,
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
