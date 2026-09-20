import 'dart:ui';

import 'package:get/get.dart';

import 'strings_ar.dart';
import 'strings_bn.dart';
import 'strings_en.dart';
import 'strings_es.dart';
import 'strings_hi.dart';
import 'strings_id.dart';
import 'strings_pt.dart';

/// One language the app can be read in.
class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
  });

  /// The language tag stored in settings and passed to [Locale].
  final String code;

  /// The name as its own speakers write it, which is what the picker shows:
  /// someone looking for their language will not be reading English to find
  /// it.
  final String nativeName;

  /// The same name in English, shown underneath as a second chance to
  /// recognise it.
  final String englishName;

  Locale get locale => Locale(code);
}

/// Every string the app shows, in every language it speaks.
///
/// GetX rather than generated Flutter localisations: tool names, failure
/// messages and greetings are built in enums, repositories and controllers,
/// none of which have a [BuildContext] to look a translation up with.
class AppTranslations extends Translations {
  /// The languages offered, in the order the picker lists them.
  ///
  /// English first as the fallback, then the languages this app is most
  /// likely to be read in.
  static const List<AppLanguage> languages = <AppLanguage>[
    AppLanguage(code: 'en', nativeName: 'English', englishName: 'English'),
    AppLanguage(code: 'bn', nativeName: 'বাংলা', englishName: 'Bengali'),
    AppLanguage(code: 'hi', nativeName: 'हिन्दी', englishName: 'Hindi'),
  ];

  /// The language used when nothing else applies: a phone set to a language
  /// this app does not speak, or a key missing from a translation.
  static const Locale fallbackLocale = Locale('en');

  static List<Locale> get supportedLocales => languages
      .map((AppLanguage language) => language.locale)
      .toList(growable: false);

  /// The language for a stored code, or null when there is no such language.
  ///
  /// Null also for a stored code the app no longer offers, so a language
  /// dropped in a later version falls back rather than showing nothing.
  static AppLanguage? languageFor(String? code) {
    if (code == null) {
      return null;
    }
    for (final AppLanguage language in languages) {
      if (language.code == code) {
        return language;
      }
    }
    return null;
  }

  /// The language to start in: the saved choice, else the phone's own
  /// language when the app speaks it, else English.
  static Locale resolveLocale(String? savedCode, Locale? deviceLocale) {
    final AppLanguage? saved = languageFor(savedCode);
    if (saved != null) {
      return saved.locale;
    }
    final AppLanguage? device = languageFor(deviceLocale?.languageCode);
    return device?.locale ?? fallbackLocale;
  }

  /// Loads the strings without a [GetMaterialApp] to do it.
  ///
  /// The app itself gets them from the `translations` argument; this is for
  /// anything that reads text outside a running app, such as a widget test
  /// that pumps a single screen.
  static void install({Locale locale = fallbackLocale}) {
    Get.addTranslations(AppTranslations().keys);
    Get.locale = locale;
    Get.fallbackLocale = fallbackLocale;
  }

  @override
  Map<String, Map<String, String>> get keys => <String, Map<String, String>>{
    'en': stringsEn,
    'bn': stringsBn,
    'hi': stringsHi,
    // Kept for users upgrading from an older release. These locales are no
    // longer offered, but retaining their strings lets GetX complete a live
    // locale migration before the saved setting falls back to English.
    'id': stringsId,
    'pt': stringsPt,
    'es': stringsEs,
    'ar': stringsAr,
  };
}
