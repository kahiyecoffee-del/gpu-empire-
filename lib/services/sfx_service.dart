import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum Sfx { tap, buy, milestone, reward, fanfare, spin, whoosh }

/// Short sound effects. Behind an interface so tests stay silent.
abstract interface class SfxService {
  Future<void> prepare();

  void play(Sfx sfx);
}

class SilentSfxService implements SfxService {
  const SilentSfxService();

  @override
  Future<void> prepare() async {}

  @override
  void play(Sfx sfx) {}
}

/// A few players per effect, used round-robin, so quick repeats (taps)
/// overlap instead of cutting each other off.
class PooledSfxService implements SfxService {
  PooledSfxService({this.voices = 3});

  final int voices;
  final Map<Sfx, List<AudioPlayer>> _pools = {};
  final Map<Sfx, int> _next = {};

  static const _volume = {
    Sfx.tap: 0.35,
    Sfx.buy: 0.6,
    Sfx.milestone: 0.7,
    Sfx.reward: 0.7,
    Sfx.fanfare: 0.8,
    Sfx.spin: 0.6,
    Sfx.whoosh: 0.4,
  };

  @override
  Future<void> prepare() async {
    for (final sfx in Sfx.values) {
      final players = <AudioPlayer>[];
      for (var i = 0; i < voices; i++) {
        final player = AudioPlayer();
        try {
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setVolume(_volume[sfx]!);
          await player.setSource(AssetSource('audio/sfx_${sfx.name}.mp3'));
          players.add(player);
        } on Object {
          // Sounds are a nicety: a failed load must never break the game.
        }
      }
      _pools[sfx] = players;
    }
  }

  @override
  void play(Sfx sfx) {
    final pool = _pools[sfx];
    if (pool == null || pool.isEmpty) return;
    final i = (_next[sfx] ?? 0) % pool.length;
    _next[sfx] = i + 1;
    // resume() first, inside the tap, so mobile browsers allow it; with
    // ReleaseMode.stop a finished player is back at the start.
    pool[i].resume().ignore();
  }
}

/// Overridden in `main`; silent by default (tests).
final sfxServiceProvider = Provider<SfxService>(
  (ref) => const SilentSfxService(),
);
