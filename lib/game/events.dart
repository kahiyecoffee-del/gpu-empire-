import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/economy_config.dart';
import 'game_controller.dart';

/// A random event waiting to be tapped.
class ActiveEvent {
  const ActiveEvent(this.event, this.secondsLeft);

  final EventConfig event;
  final double secondsLeft;
}

final eventProvider = NotifierProvider<EventController, ActiveEvent?>(
  EventController.new,
);

/// Spawns a random event every few minutes of play and expires it if the
/// player does not tap it in time.
class EventController extends Notifier<ActiveEvent?> {
  final _random = math.Random();
  double _untilNext = 0;

  EventsConfig get _config => ref.read(economyConfigProvider).events;

  @override
  ActiveEvent? build() {
    _untilNext = _nextDelay();
    return null;
  }

  double _nextDelay() =>
      _config.minInterval +
      _random.nextDouble() * (_config.maxInterval - _config.minInterval);

  /// Advances event timers by [dt] seconds of play.
  void advance(double dt) {
    final active = state;
    if (active != null) {
      final left = active.secondsLeft - dt;
      state = left > 0 ? ActiveEvent(active.event, left) : null;
      return;
    }
    if (_config.list.isEmpty) return;
    _untilNext -= dt;
    if (_untilNext > 0) return;
    _untilNext = _nextDelay();
    state = ActiveEvent(_pick(), _config.lifetime);
  }

  EventConfig _pick() {
    final total = _config.list.fold(0.0, (sum, e) => sum + e.weight);
    var roll = _random.nextDouble() * total;
    for (final e in _config.list) {
      roll -= e.weight;
      if (roll <= 0) return e;
    }
    return _config.list.last;
  }

  /// Shows a random event right away (developer menu).
  void spawnNow() => state = ActiveEvent(_pick(), _config.lifetime);

  /// Collects the active event, applying its reward.
  void collect() {
    final event = take();
    if (event != null) ref.read(gameProvider.notifier).collectEvent(event);
  }

  /// Removes the active event without applying it, so it cannot expire
  /// while the player watches an ad for the doubled reward.
  EventConfig? take() {
    final event = state?.event;
    state = null;
    return event;
  }
}
