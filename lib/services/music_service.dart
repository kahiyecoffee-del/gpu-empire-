import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Background music. Behind an interface so tests and platforms without
/// audio can use [SilentMusicService].
abstract interface class MusicService {
  /// Loads the track ahead of time so [play] can start it instantly.
  Future<void> prepare();

  /// Starts or resumes the loop. Browsers only allow this right after the
  /// player touches the page, so it is called from input handlers.
  Future<void> play();

  Future<void> pause();
}

class SilentMusicService implements MusicService {
  const SilentMusicService();

  @override
  Future<void> prepare() async {}

  @override
  Future<void> play() async {}

  @override
  Future<void> pause() async {}
}

class LoopingMusicService implements MusicService {
  LoopingMusicService({this.asset = 'audio/music_loop.mp3', this.volume = 0.4});

  final String asset;
  final double volume;

  final AudioPlayer _player = AudioPlayer();
  bool _playing = false;

  @override
  Future<void> prepare() async {
    try {
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(volume);
      await _player.setSource(AssetSource(asset));
    } on Object {
      // Audio is a nicety: a failed load must never break the game.
    }
  }

  @override
  Future<void> play() async {
    if (_playing) return;
    _playing = true;
    try {
      // resume() is the first call, so mobile browsers still see it as
      // part of the tap that triggered it.
      await _player.resume();
    } on Object {
      _playing = false;
    }
  }

  @override
  Future<void> pause() async {
    if (!_playing) return;
    _playing = false;
    try {
      await _player.pause();
    } on Object {
      // Ignore, see prepare().
    }
  }
}

/// Overridden in `main`; silent by default (tests).
final musicServiceProvider = Provider<MusicService>(
  (ref) => const SilentMusicService(),
);
