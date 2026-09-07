import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/initial_binding.dart';
import 'core/constants/app_constants.dart';
import 'core/routes/app_pages.dart';
import 'core/services/ads_service.dart';
import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/neon_backdrop.dart';
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

  runApp(const ConvertlyApp());
}

class ConvertlyApp extends StatelessWidget {
  const ConvertlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: Get.find<SettingsController>().themeMode,
      builder: (BuildContext context, Widget? child) =>
          NeonBackdrop(child: child ?? const SizedBox.shrink()),
      initialRoute: AppPages.initial,
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
