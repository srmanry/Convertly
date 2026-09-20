import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/i18n/strings_en.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final AppTranslations translations = AppTranslations();

  test('only English, Bengali, and Hindi are offered', () {
    expect(
      AppTranslations.languages.map((AppLanguage language) => language.code),
      <String>['en', 'bn', 'hi'],
    );
  });

  test('every offered language has a set of strings behind it', () {
    for (final AppLanguage language in AppTranslations.languages) {
      expect(
        translations.keys[language.code],
        isNotNull,
        reason: '${language.englishName} is offered but has no translation',
      );
    }
  });

  test('no language is missing a string', () {
    // A missing key falls back to English at runtime, so this never crashes;
    // it shows one English line in the middle of another language, which is
    // exactly the kind of thing nobody notices until a user reports it.
    translations.keys.forEach((String code, Map<String, String> strings) {
      final Set<String> missing = stringsEn.keys.toSet()
        ..removeAll(strings.keys);
      expect(missing, isEmpty, reason: '$code is missing: $missing');
    });
  });

  test('no language carries a string the app no longer uses', () {
    translations.keys.forEach((String code, Map<String, String> strings) {
      final Set<String> extra = strings.keys.toSet()..removeAll(stringsEn.keys);
      expect(extra, isEmpty, reason: '$code has stale keys: $extra');
    });
  });

  test('every placeholder in English survives translation', () {
    // '@count' filled by trParams has to exist in the translated text too,
    // or the number simply never appears in that language.
    final RegExp placeholder = RegExp(r'@[a-zA-Z]+');

    translations.keys.forEach((String code, Map<String, String> strings) {
      stringsEn.forEach((String key, String english) {
        final Set<String> expected = placeholder
            .allMatches(english)
            .map((RegExpMatch match) => match.group(0)!)
            .toSet();
        if (expected.isEmpty) {
          return;
        }
        final Set<String> actual = placeholder
            .allMatches(strings[key] ?? '')
            .map((RegExpMatch match) => match.group(0)!)
            .toSet();
        expect(
          actual,
          containsAll(expected),
          reason: '$code "$key" drops a placeholder',
        );
      });
    });
  });

  test('no string is left empty', () {
    translations.keys.forEach((String code, Map<String, String> strings) {
      strings.forEach((String key, String value) {
        expect(value.trim(), isNotEmpty, reason: '$code "$key" is blank');
      });
    });
  });

  group('picking the language to start in', () {
    test('a saved choice wins over the phone', () {
      expect(
        AppTranslations.resolveLocale('bn', const Locale('es')),
        const Locale('bn'),
      );
    });

    test('with nothing saved, a supported phone language is used', () {
      expect(
        AppTranslations.resolveLocale(null, const Locale('hi')),
        const Locale('hi'),
      );
    });

    test('a phone language the app does not speak falls back to English', () {
      expect(
        AppTranslations.resolveLocale(null, const Locale('ja')),
        const Locale('en'),
      );
    });

    test(
      'a saved language the app dropped falls back rather than sticking',
      () {
        expect(
          AppTranslations.resolveLocale('xx', const Locale('ja')),
          const Locale('en'),
        );
      },
    );
  });
}
