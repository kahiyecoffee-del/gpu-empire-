import 'package:flutter/widgets.dart';

/// Languages the game ships in, with their own names. Order: English
/// first, then roughly by number of speakers.
const languages = <(String, String)>[
  ('en', 'English'),
  ('zh', '简体中文'),
  ('hi', 'हिन्दी'),
  ('es', 'Español'),
  ('fr', 'Français'),
  ('ar', 'العربية'),
  ('bn', 'বাংলা'),
  ('pt', 'Português'),
  ('ru', 'Русский'),
  ('ur', 'اردو'),
  ('id', 'Bahasa Indonesia'),
  ('de', 'Deutsch'),
  ('ja', '日本語'),
  ('mr', 'मराठी'),
  ('te', 'తెలుగు'),
  ('tr', 'Türkçe'),
  ('ta', 'தமிழ்'),
  ('zh_Hant', '繁體中文'),
  ('vi', 'Tiếng Việt'),
  ('ko', '한국어'),
  ('fa', 'فارسی'),
  ('sw', 'Kiswahili'),
  ('it', 'Italiano'),
  ('th', 'ไทย'),
  ('gu', 'ગુજરાતી'),
  ('am', 'አማርኛ'),
  ('kn', 'ಕನ್ನಡ'),
  ('pl', 'Polski'),
  ('uk', 'Українська'),
  ('ml', 'മലയാളം'),
  ('pa', 'ਪੰਜਾਬੀ'),
  ('fil', 'Filipino'),
  ('ms', 'Bahasa Melayu'),
  ('nl', 'Nederlands'),
  ('ro', 'Română'),
];

/// `zh_Hant` -> Locale(zh, script Hant); `de` -> Locale(de).
Locale localeFromTag(String tag) {
  final parts = tag.split('_');
  return parts.length == 2
      ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
      : Locale(parts[0]);
}

String languageName(String tag) =>
    languages.firstWhere((l) => l.$1 == tag, orElse: () => languages[0]).$2;

/// Picks the best supported locale for the device's preferred languages:
/// Traditional Chinese for Taiwan/Hong Kong/Macau or the Hant script, else
/// the first language we have, else English.
Locale resolveLocale(List<Locale>? preferred, Iterable<Locale> supported) {
  for (final p in preferred ?? const <Locale>[]) {
    if (p.languageCode == 'zh') {
      final traditional =
          p.scriptCode == 'Hant' ||
          const {'TW', 'HK', 'MO'}.contains(p.countryCode);
      return traditional ? localeFromTag('zh_Hant') : const Locale('zh');
    }
    // Android reports Filipino as "tl" on some devices.
    final code = p.languageCode == 'tl' ? 'fil' : p.languageCode;
    for (final s in supported) {
      if (s.languageCode == code && s.scriptCode == null) return s;
    }
  }
  return const Locale('en');
}
