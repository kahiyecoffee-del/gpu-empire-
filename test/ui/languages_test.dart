import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/l10n/app_localizations.dart';
import 'package:gpuempire/ui/languages.dart';

void main() {
  const supported = AppLocalizations.supportedLocales;

  test('35 languages, each with a translation', () {
    expect(languages, hasLength(35));
    expect(languages.map((l) => l.$1).toSet(), hasLength(35));
    for (final (tag, _) in languages) {
      expect(supported, contains(localeFromTag(tag)), reason: tag);
    }
  });

  test('the device language is used when we have it', () {
    expect(
      resolveLocale([const Locale('de', 'AT')], supported),
      const Locale('de'),
    );
    expect(
      resolveLocale([const Locale('xx'), const Locale('ja', 'JP')], supported),
      const Locale('ja'),
    );
    expect(resolveLocale([const Locale('xx')], supported), const Locale('en'));
    expect(resolveLocale(null, supported), const Locale('en'));
  });

  test('Chinese picks the script from region or script code', () {
    expect(
      resolveLocale([const Locale('zh', 'CN')], supported),
      const Locale('zh'),
    );
    expect(
      resolveLocale([const Locale('zh', 'TW')], supported),
      localeFromTag('zh_Hant'),
    );
    expect(
      resolveLocale([
        const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'),
      ], supported),
      localeFromTag('zh_Hant'),
    );
  });

  test('Filipino reported as tl still matches', () {
    expect(resolveLocale([const Locale('tl')], supported), const Locale('fil'));
  });
}
