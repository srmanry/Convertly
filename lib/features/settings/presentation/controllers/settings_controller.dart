import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/audio_format.dart';
import '../../../../core/enums/audio_quality.dart';
import '../../../../core/i18n/app_translations.dart';
import '../../../../core/i18n/translation_keys.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/usecases/get_settings.dart';
import '../../domain/usecases/save_settings.dart';

/// App-wide settings state.
///
/// Registered permanently during bootstrap because the theme depends on it, so
/// it must outlive any single route.
class SettingsController extends GetxController {
  SettingsController(this._getSettings, this._saveSettings);

  final GetSettings _getSettings;
  final SaveSettings _saveSettings;

  final Rx<AppSettings> settings = const AppSettings().obs;
  final RxBool isLoading = false.obs;

  ThemeMode get themeMode => switch (settings.value.themeMode) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };

  /// Loads persisted settings.
  ///
  /// Awaited during bootstrap rather than fired from `onInit`, so the first
  /// frame already renders with the saved theme.
  Future<void> load() async {
    isLoading.value = true;
    final result = await _getSettings(const NoParams());
    // On failure the in-memory defaults stay in place; the user is not blocked.
    if (result.valueOrNull case final AppSettings loaded) {
      settings.value = loaded;
    }
    isLoading.value = false;
  }

  Future<void> setThemeMode(AppThemeMode mode) async {
    await _update(settings.value.copyWith(themeMode: mode));
    Get.changeThemeMode(themeMode);
  }

  Future<void> setDefaultOutputFormat(AudioFormat format) =>
      _update(settings.value.copyWith(defaultOutputFormat: format));

  Future<void> setDefaultAudioQuality(AudioQuality quality) =>
      _update(settings.value.copyWith(defaultAudioQuality: quality));

  /// The language in use, which is the saved one unless nothing is saved and
  /// the phone's own language is one the app speaks.
  AppLanguage get language =>
      AppTranslations.languageFor(
        AppTranslations.resolveLocale(
          settings.value.languageCode,
          Get.deviceLocale,
        ).languageCode,
      ) ??
      AppTranslations.languages.first;

  /// Switches the language and redraws every screen in it.
  ///
  /// Applied before saving so the change is instant; a save that fails is
  /// reverted by [_update] along with the rest of the settings.
  Future<void> setLanguageCode(String code) async {
    final AppLanguage? picked = AppTranslations.languageFor(code);
    if (picked == null) {
      return;
    }
    await Get.updateLocale(picked.locale);
    await _update(settings.value.copyWith(languageCode: code));
  }

  /// Applies optimistically, then reverts if persistence failed so the UI never
  /// shows a preference that was not actually saved.
  Future<void> _update(AppSettings updated) async {
    final AppSettings previous = settings.value;
    settings.value = updated;

    final result = await _saveSettings(updated);
    result.fold((failure) {
      settings.value = previous;
      Get.snackbar(
        K.navSettings.tr,
        failure.message,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16),
      );
    }, (saved) => settings.value = saved);
  }
}
