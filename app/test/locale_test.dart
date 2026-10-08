import 'package:flutter_test/flutter_test.dart';
import 'package:skidsense_app/app.dart';
import 'package:skidsense_app/l10n/gen/app_localizations.dart';
import 'package:skidsense_app/main.dart';
import 'package:skidsense_app/state/appearance.dart';
import 'package:skidsense_app/ui/material.dart';

void main() {
  const hans = Locale('zh');
  const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  Locale resolve(List<Locale> preferred) => resolveLocale(preferred, L10n.supportedLocales);

  test('Chinese is told apart by script, then by region', () {
    expect(resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant', countryCode: 'CN')]), hant);
    expect(resolve(const [Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans', countryCode: 'TW')]), hans);
    for (final region in ['TW', 'HK', 'MO']) {
      expect(resolve([Locale('zh', region)]), hant, reason: region);
    }
    for (final region in ['CN', 'SG', 'MY']) {
      expect(resolve([Locale('zh', region)]), hans, reason: region);
    }
    expect(resolve(const [Locale('zh')]), hans);
  });

  test('the first language the app speaks wins; otherwise English', () {
    expect(resolve(const [Locale('fr'), Locale('zh', 'TW'), Locale('en')]), hant);
    expect(resolve(const [Locale('ja'), Locale('en', 'GB'), Locale('zh')]), const Locale('en'));
    expect(resolve(const [Locale('ja')]), const Locale('en'));
    expect(resolve(const []), const Locale('en'));
  });

  test('every chosen language resolves to a supported locale', () {
    for (final language in AppLanguage.values) {
      final locale = language.locale;
      if (locale == null) continue;
      expect(L10n.supportedLocales, contains(resolve([locale])), reason: language.name);
    }
  });

  test('the backend hears the same language the app shows', () {
    expect(backendLanguage(AppLanguage.simplifiedChinese, const [Locale('en')]), 'zh-CN');
    expect(backendLanguage(AppLanguage.traditionalChinese, const [Locale('en')]), 'zh-TW');
    expect(backendLanguage(AppLanguage.english, const [Locale('zh', 'TW')]), 'en');
    expect(backendLanguage(AppLanguage.system, const [Locale('zh', 'HK')]), 'zh-TW');
    expect(backendLanguage(AppLanguage.system, const [Locale('zh', 'CN')]), 'zh-CN');
    expect(backendLanguage(AppLanguage.system, const [Locale('de')]), 'en');
  });
}
