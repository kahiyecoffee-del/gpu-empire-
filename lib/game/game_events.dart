import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Things that happen in the game, for sounds, celebrations and analytics.
enum GameEventType {
  sessionStart,
  tap,
  buyLevels,
  lineUnlock,
  milestone,
  hireManager,
  buyUpgrade,
  buyInfra,
  buySkill,
  move,
  ipo,
  questClaim,
  eventCollect,
  wheelSpin,
  timeWarp,
  adRewardStart,
  adRewardComplete,
  adInterstitial,
  purchase,
  tutorialStep,
}

class GameEvent {
  const GameEvent(this.type, [this.params = const {}]);

  final GameEventType type;

  /// Analytics parameters (strings and numbers only).
  final Map<String, Object> params;

  @override
  String toString() => params.isEmpty ? type.name : '${type.name} $params';
}

/// A synchronous broadcast stream of [GameEvent]s.
final gameEventsProvider = Provider<GameEventBus>((ref) {
  final bus = GameEventBus();
  ref.onDispose(bus.close);
  return bus;
});

class GameEventBus {
  final _controller = StreamController<GameEvent>.broadcast(sync: true);

  Stream<GameEvent> get stream => _controller.stream;

  void emit(GameEventType type, [Map<String, Object> params = const {}]) {
    if (!_controller.isClosed) _controller.add(GameEvent(type, params));
  }

  void close() => unawaited(_controller.close());
}
