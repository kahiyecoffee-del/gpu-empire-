import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences. Kept apart from the game save so a progress reset
/// does not touch them.
class Settings {
  const Settings({
    this.musicOn = true,
    this.sfxOn = true,
    this.introSeen = false,
    this.tutorialDone = false,
    this.infraHintSeen = false,
    this.language,
  });

  final bool musicOn;
  final bool sfxOn;

  /// Whether Max's first-launch greeting was shown.
  final bool introSeen;

  /// Whether the first-minutes tutorial was finished or skipped.
  final bool tutorialDone;

  /// Whether the one-time "you are throttled" hint was shown.
  final bool infraHintSeen;

  /// Chosen language tag (e.g. `de`, `zh_Hant`), or null to follow the
  /// device.
  final String? language;

  Settings copyWith({
    bool? musicOn,
    bool? sfxOn,
    bool? introSeen,
    bool? tutorialDone,
    bool? infraHintSeen,
    String? language,
    bool clearLanguage = false,
  }) => Settings(
    musicOn: musicOn ?? this.musicOn,
    sfxOn: sfxOn ?? this.sfxOn,
    introSeen: introSeen ?? this.introSeen,
    tutorialDone: tutorialDone ?? this.tutorialDone,
    infraHintSeen: infraHintSeen ?? this.infraHintSeen,
    language: clearLanguage ? null : language ?? this.language,
  );
}

/// Overridden in `main` with the loaded instance.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) =>
      throw UnimplementedError('sharedPreferencesProvider must be overridden'),
);

final settingsProvider = NotifierProvider<SettingsController, Settings>(
  SettingsController.new,
);

class SettingsController extends Notifier<Settings> {
  static const _musicKey = 'settings_music_on';
  static const _sfxKey = 'settings_sfx_on';
  static const _introKey = 'settings_intro_seen';
  static const _tutorialKey = 'settings_tutorial_done';
  static const _infraHintKey = 'settings_infra_hint_seen';
  static const _languageKey = 'settings_language';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Settings(
      musicOn: prefs.getBool(_musicKey) ?? true,
      sfxOn: prefs.getBool(_sfxKey) ?? true,
      introSeen: prefs.getBool(_introKey) ?? false,
      tutorialDone: prefs.getBool(_tutorialKey) ?? false,
      infraHintSeen: prefs.getBool(_infraHintKey) ?? false,
      language: prefs.getString(_languageKey),
    );
  }

  Future<void> setMusic({required bool on}) async {
    state = state.copyWith(musicOn: on);
    await _prefs.setBool(_musicKey, on);
  }

  Future<void> setSfx({required bool on}) async {
    state = state.copyWith(sfxOn: on);
    await _prefs.setBool(_sfxKey, on);
  }

  Future<void> markIntroSeen() async {
    state = state.copyWith(introSeen: true);
    await _prefs.setBool(_introKey, true);
  }

  Future<void> setTutorialDone({required bool done}) async {
    state = state.copyWith(tutorialDone: done);
    await _prefs.setBool(_tutorialKey, done);
  }

  Future<void> setInfraHintSeen() async {
    state = state.copyWith(infraHintSeen: true);
    await _prefs.setBool(_infraHintKey, true);
  }

  /// Null follows the device language.
  Future<void> setLanguage(String? tag) async {
    state = tag == null
        ? state.copyWith(clearLanguage: true)
        : state.copyWith(language: tag);
    if (tag == null) {
      await _prefs.remove(_languageKey);
    } else {
      await _prefs.setString(_languageKey, tag);
    }
  }
}
