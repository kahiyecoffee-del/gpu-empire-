import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Player preferences. Kept apart from the game save so a progress reset
/// does not touch them.
class Settings {
  const Settings({this.musicOn = true, this.introSeen = false});

  final bool musicOn;

  /// Whether Max's first-launch greeting was shown.
  final bool introSeen;

  Settings copyWith({bool? musicOn, bool? introSeen}) => Settings(
    musicOn: musicOn ?? this.musicOn,
    introSeen: introSeen ?? this.introSeen,
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
  static const _introKey = 'settings_intro_seen';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  Settings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return Settings(
      musicOn: prefs.getBool(_musicKey) ?? true,
      introSeen: prefs.getBool(_introKey) ?? false,
    );
  }

  Future<void> setMusic({required bool on}) async {
    state = state.copyWith(musicOn: on);
    await _prefs.setBool(_musicKey, on);
  }

  Future<void> markIntroSeen() async {
    state = state.copyWith(introSeen: true);
    await _prefs.setBool(_introKey, true);
  }
}
