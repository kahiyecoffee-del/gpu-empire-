import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/economy_config.dart';
import '../core/game_state.dart';
import 'save_migrations.dart';

/// Where the save JSON is kept. Abstracted so tests can use memory.
abstract interface class SaveStore {
  Future<String?> read();
  Future<void> write(String data);
  Future<void> clear();
}

/// Stores the save in shared_preferences: native storage on Android/iOS,
/// localStorage on the web.
class PrefsSaveStore implements SaveStore {
  PrefsSaveStore(this._prefs);

  static const _key = 'gpu_empire_save';

  final SharedPreferences _prefs;

  @override
  Future<String?> read() async => _prefs.getString(_key);

  @override
  Future<void> write(String data) => _prefs.setString(_key, data);

  @override
  Future<void> clear() => _prefs.remove(_key);
}

class MemorySaveStore implements SaveStore {
  String? data;

  @override
  Future<String?> read() async => data;

  @override
  Future<void> write(String value) async => data = value;

  @override
  Future<void> clear() async => data = null;
}

/// A loaded save.
class SaveSnapshot {
  const SaveSnapshot({required this.state, required this.lastSeenMs});

  final GameState state;

  /// Latest wall-clock time ever recorded, used for offline earnings.
  final int lastSeenMs;
}

/// Serializes the game with a version number so old saves can be migrated.
class SaveService {
  SaveService(this._store, this._config, {int Function()? clock})
    : _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch);

  final SaveStore _store;
  final EconomyConfig _config;
  final int Function() _clock;

  /// Highest timestamp seen so far; never moves backwards.
  int _lastSeenMs = 0;

  int now() => _clock();

  /// A stored time this far ahead of the clock is treated as a clock that
  /// was wrong once, not as cheating.
  static const _maxAheadMs = 24 * 3600 * 1000;

  /// Never moves backwards (turning the clock back and forth must not pay
  /// the same hours twice), unless the stored time is more than a day in
  /// the future: then it snaps back, so a wrong clock cannot block offline
  /// earnings forever.
  int _advance(int stored, int candidate) {
    final latest = math.max(stored, candidate);
    return latest - now() > _maxAheadMs ? now() : latest;
  }

  /// Returns null when there is no save or it cannot be read.
  Future<SaveSnapshot?> load() async {
    final raw = await _store.read();
    if (raw == null) return null;
    try {
      final json = migrateSave(jsonDecode(raw) as Map<String, Object?>);
      final lastSeen = (json['lastSeenMs']! as num).toInt();
      _lastSeenMs = _advance(_lastSeenMs, lastSeen);
      return SaveSnapshot(
        state: GameState.fromJson(
          json['state']! as Map<String, Object?>,
          _config,
        ),
        lastSeenMs: lastSeen,
      );
    } on Object {
      // A corrupt save must not brick the game; start over instead.
      return null;
    }
  }

  /// Writes [state]. With [touch] false the last-seen time is kept, so a
  /// save while the app is in the background (a store purchase) does not
  /// swallow offline earnings.
  Future<void> save(GameState state, {bool touch = true}) {
    if (touch) _lastSeenMs = _advance(_lastSeenMs, now());
    return _store.write(
      jsonEncode({
        'version': currentSaveVersion,
        'lastSeenMs': _lastSeenMs,
        'state': state.toJson(_config),
      }),
    );
  }

  /// The latest timestamp the save knows about.
  int get lastSeenMs => _lastSeenMs;

  Future<void> clear() {
    _lastSeenMs = 0;
    return _store.clear();
  }
}

/// Overridden in `main` with the real service.
final saveServiceProvider = Provider<SaveService>(
  (ref) => throw UnimplementedError('saveServiceProvider must be overridden'),
);
