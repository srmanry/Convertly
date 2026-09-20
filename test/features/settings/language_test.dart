import 'package:convertly/core/enums/tool_mode.dart';
import 'package:convertly/core/errors/failure.dart';
import 'package:convertly/core/i18n/app_translations.dart';
import 'package:convertly/core/i18n/strings_bn.dart';
import 'package:convertly/core/i18n/strings_en.dart';
import 'package:convertly/core/i18n/translation_keys.dart';
import 'package:convertly/core/theme/app_theme.dart';
import 'package:convertly/features/settings/domain/entities/app_settings.dart';
import 'package:convertly/features/settings/domain/repositories/settings_repository.dart';
import 'package:convertly/features/settings/domain/usecases/get_settings.dart';
import 'package:convertly/features/settings/domain/usecases/save_settings.dart';
import 'package:convertly/core/types/result.dart';
import 'package:convertly/features/settings/presentation/controllers/settings_controller.dart';
import 'package:convertly/features/settings/presentation/pages/settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

/// Settings that live in memory, so a language change can be read back
/// without touching real storage.
class _InMemorySettingsRepository implements SettingsRepository {
  AppSettings stored = const AppSettings();

  @override
  Future<Result<AppSettings>> getSettings() async =>
      Result<AppSettings>.success(stored);

  @override
  Future<Result<AppSettings>> saveSettings(AppSettings settings) async {
    stored = settings;
    return Result<AppSettings>.success(settings);
  }
}

void main() {
  late _InMemorySettingsRepository repository;
  late SettingsController controller;

  setUp(() {
    repository = _InMemorySettingsRepository();
    controller = SettingsController(
      GetSettings(repository),
      SaveSettings(repository),
    );
    Get.put<SettingsController>(controller);
  });

  tearDown(() {
    Get.reset();
    Get.locale = AppTranslations.fallbackLocale;
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    Locale locale = AppTranslations.fallbackLocale,
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.dark,
        translations: AppTranslations(),
        locale: locale,
        fallbackLocale: AppTranslations.fallbackLocale,
        supportedLocales: AppTranslations.supportedLocales,
        localizationsDelegates: const <LocalizationsDelegate<Object>>[
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the language row shows the language being read', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    expect(find.text(stringsEn[K.language]!), findsOneWidget);
    expect(find.text('English'), findsWidgets);
  });

  testWidgets('a screen is drawn in whichever language is set', (
    WidgetTester tester,
  ) async {
    Get.locale = const Locale('bn');

    await pumpSettings(tester, locale: const Locale('bn'));

    expect(find.text(stringsBn[K.settingsConversion]!), findsOneWidget);
    expect(find.text(stringsBn[K.privacyPolicy]!), findsOneWidget);
    expect(find.text(stringsEn[K.privacyPolicy]!), findsNothing);
  });

  testWidgets('the picker offers only English, Bengali, and Hindi', (
    WidgetTester tester,
  ) async {
    await pumpSettings(tester);

    await tester.tap(find.text(stringsEn[K.language]!));
    await tester.pumpAndSettle();

    // The picker lists languages by their own names, which is what someone
    // looking for theirs will be reading.
    expect(find.text('বাংলা'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('Español'), findsNothing);
    expect(find.text('العربية'), findsNothing);

    Navigator.of(tester.element(find.text('বাংলা'))).pop();
    await tester.pumpAndSettle();
  });

  test('text built outside a widget follows the language too', () {
    // Tool names and failure messages are built in enums and repositories,
    // where there is no BuildContext to look a translation up with.
    Get.locale = const Locale('bn');
    addTearDown(() => Get.locale = AppTranslations.fallbackLocale);

    expect(ToolMode.cut.title, stringsBn[K.toolCut]);
    expect(const ConversionFailure().message, stringsBn[K.errorConversion]);

    Get.locale = const Locale('en');

    expect(ToolMode.cut.title, stringsEn[K.toolCut]);
  });
}
