import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_controller.dart';

/// Drives the simulation from the frame clock.
class GameLoop extends ConsumerStatefulWidget {
  const GameLoop({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<GameLoop> createState() => _GameLoopState();
}

class _GameLoopState extends ConsumerState<GameLoop>
    with SingleTickerProviderStateMixin {
  /// Longest step simulated per frame. Longer pauses (app in background) are
  /// handled by offline earnings instead of one giant frame.
  static const _maxFrameSeconds = 0.25;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / Duration.microsecondsPerSecond;
    _last = elapsed;
    if (dt <= 0) return;
    if (dt > _maxFrameSeconds) dt = _maxFrameSeconds;
    final scale = ref.read(devSettingsProvider).timeScale;
    ref.read(gameProvider.notifier).tick(dt * scale);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
