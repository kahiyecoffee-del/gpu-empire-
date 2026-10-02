import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_events.dart';
import '../services/settings_service.dart';
import '../services/sfx_service.dart';

/// The sound played for a game event, if any.
Sfx? soundFor(GameEventType type) => switch (type) {
  GameEventType.tap => Sfx.tap,
  GameEventType.buyLevels ||
  GameEventType.hireManager ||
  GameEventType.buyUpgrade ||
  GameEventType.buyInfra ||
  GameEventType.buySkill => Sfx.buy,
  GameEventType.milestone || GameEventType.lineUnlock => Sfx.milestone,
  GameEventType.questClaim ||
  GameEventType.eventCollect ||
  GameEventType.adRewardComplete ||
  GameEventType.timeWarp ||
  GameEventType.purchase => Sfx.reward,
  GameEventType.ipo || GameEventType.move => Sfx.fanfare,
  GameEventType.wheelSpin => Sfx.spin,
  _ => null,
};

/// Plays sound effects for game events when effects are on.
class SfxDirector extends ConsumerStatefulWidget {
  const SfxDirector({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SfxDirector> createState() => _SfxDirectorState();
}

class _SfxDirectorState extends ConsumerState<SfxDirector> {
  StreamSubscription<GameEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(gameEventsProvider).stream.listen(_onEvent);
  }

  void _onEvent(GameEvent e) {
    if (!ref.read(settingsProvider).sfxOn) return;
    final sfx = soundFor(e.type);
    if (sfx != null) ref.read(sfxServiceProvider).play(sfx);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Plays [sfx] directly (for moments that are not game events), if sound
/// effects are on.
void playSfx(WidgetRef ref, Sfx sfx) {
  if (ref.read(settingsProvider).sfxOn) ref.read(sfxServiceProvider).play(sfx);
}
