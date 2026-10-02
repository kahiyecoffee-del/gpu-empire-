import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/music_service.dart';
import '../services/settings_service.dart';

/// Plays the background music while the app is visible and music is on.
///
/// Playback starts on the player's first touch, because browsers (iOS Safari
/// in particular) refuse to start audio before any interaction.
class MusicDirector extends ConsumerStatefulWidget {
  const MusicDirector({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MusicDirector> createState() => _MusicDirectorState();
}

class _MusicDirectorState extends ConsumerState<MusicDirector> {
  late final AppLifecycleListener _lifecycle;
  bool _touched = false;
  bool _visible = true;

  MusicService get _music => ref.read(musicServiceProvider);

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onHide: () {
        _visible = false;
        _music.pause();
      },
      onShow: () {
        _visible = true;
        _sync();
      },
    );
  }

  void _sync() {
    if (_touched && _visible && ref.read(settingsProvider).musicOn) {
      _music.play();
    } else {
      _music.pause();
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(settingsProvider.select((s) => s.musicOn), (_, _) => _sync());
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerUp: (_) {
        if (_touched) return;
        _touched = true;
        _sync();
      },
      child: widget.child,
    );
  }
}
