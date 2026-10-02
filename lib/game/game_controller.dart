import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big_number.dart';
import '../core/economy_config.dart';
import '../core/economy_engine.dart';
import '../core/game_state.dart';
import '../core/monetization.dart';
import '../core/quests.dart';
import 'game_events.dart';

/// The loaded economy. Overridden in `main` once `economy.json` is read.
final economyConfigProvider = Provider<EconomyConfig>(
  (ref) => throw UnimplementedError('economyConfigProvider must be overridden'),
);

/// State to start from (a restored save). Overridden in `main`.
final initialGameStateProvider = Provider<GameState?>((ref) => null);

final engineProvider = Provider<EconomyEngine>(
  (ref) => EconomyEngine(ref.watch(economyConfigProvider)),
);

/// Side quests from `assets/config/quests.json`. Overridden in `main`.
final questsConfigProvider = Provider<List<QuestConfig>>((ref) => const []);

final questBookProvider = Provider<QuestBook>(
  (ref) =>
      QuestBook(ref.watch(engineProvider), ref.watch(questsConfigProvider)),
);

/// Story quests plus generated contracts, as Max presents them.
final questBoardProvider = Provider<QuestBoard>(
  (ref) => QuestBoard(
    ref.watch(questBookProvider),
    ContractBook(ref.watch(engineProvider)),
  ),
);

final gameProvider = NotifierProvider<GameController, GameState>(
  GameController.new,
);

enum BuyMode { one, ten, max }

final buyModeProvider = NotifierProvider<BuyModeController, BuyMode>(
  BuyModeController.new,
);

class BuyModeController extends Notifier<BuyMode> {
  @override
  BuyMode build() => BuyMode.one;

  void select(BuyMode mode) => state = mode;
}

/// A line purchase as the UI should present it.
class LineOffer {
  const LineOffer(this.count, this.cost, {required this.affordable});

  final int count;
  final BigNumber cost;
  final bool affordable;
}

/// Applies player actions to the game state. All rules live in
/// [EconomyEngine]; this class only wires them to Riverpod.
class GameController extends Notifier<GameState> {
  EconomyEngine get _engine => ref.read(engineProvider);

  void _emit(GameEventType type, [Map<String, Object> params = const {}]) =>
      ref.read(gameEventsProvider).emit(type, params);

  String _lineId(int line) => _engine.lineConfig(state, line).id;

  String get _locationId => _engine.location(state).id;

  @override
  GameState build() => ref
      .read(questBoardProvider)
      .ensure(
        ref.watch(initialGameStateProvider) ??
            GameState.initial(ref.watch(economyConfigProvider)),
      );

  void tick(double dt) => state = _engine.tick(state, dt);

  void tap(int line) {
    final next = _engine.tap(state, line);
    if (identical(next, state)) return;
    state = next;
    _emit(GameEventType.tap);
  }

  /// What the buy button of [line] offers in [mode].
  LineOffer offer(int line, BuyMode mode) {
    final count = switch (mode) {
      BuyMode.one => 1,
      BuyMode.ten => 10,
      BuyMode.max => math.max(1, _engine.maxAffordable(state, line)),
    };
    final cost = _engine.levelCost(state, line, count);
    return LineOffer(
      count,
      cost,
      affordable: _engine.isAvailable(state, line) && cost <= state.cash,
    );
  }

  /// Returns true if the purchase went through.
  bool buyLevels(int line, BuyMode mode) => _applyLevels(
    line,
    _engine.buyLevels(state, line, offer(line, mode).count),
  );

  /// Applies a level purchase and reports unlocks and milestones.
  bool _applyLevels(int line, GameState? next) {
    if (next == null) return false;
    final before = state.lines[line].level;
    final after = next.lines[line].level;
    state = next;
    final id = _lineId(line);
    _emit(GameEventType.buyLevels, {'line': id, 'level': after});
    if (before == 0) _emit(GameEventType.lineUnlock, {'line': id});
    final crossed = _engine.config.milestones
        .where((m) => m.level > before && m.level <= after)
        .length;
    if (crossed > 0) {
      _emit(GameEventType.milestone, {'line': id, 'level': after});
    }
    return true;
  }

  bool buyManager(String id) => _applyAnd(
    _engine.buyManager(state, id),
    GameEventType.hireManager,
    {'manager': id},
  );

  bool buyUpgrade(String id) => _applyAnd(
    _engine.buyUpgrade(state, id),
    GameEventType.buyUpgrade,
    {'upgrade': id},
  );

  bool buyInfra(InfraKind kind) => _applyAnd(
    _engine.buyInfra(state, kind),
    GameEventType.buyInfra,
    {'kind': kind.name},
  );

  /// Collects the quest Max is showing. Returns the reward, or null if it
  /// is not done yet.
  BigNumber? claimQuest({double factor = 1}) {
    final board = ref.read(questBoardProvider);
    final (quest, _) = board.active(state);
    final reward = board.reward(state, quest).scale(factor);
    final next = board.claim(state, factor: factor);
    if (next == null) return null;
    state = board.ensure(next);
    _emit(GameEventType.questClaim, {
      'quest': quest.id,
      'doubled': factor > 1 ? 1 : 0,
    });
    return reward;
  }

  bool moveToNextLocation() {
    final from = _locationId;
    final moved = _apply(_withContract(_engine.moveToNextLocation(state)));
    if (moved) {
      _emit(GameEventType.move, {
        'from': from,
        'to': _locationId,
        'minutes': (state.playSeconds / 60).round(),
      });
    }
    return moved;
  }

  /// Goes public. Returns the shares gained, or null if none.
  BigNumber? goPublic() {
    final gained = _engine.sharesPreview(state);
    final next = _withContract(_engine.ipo(state));
    if (next == null) return null;
    state = next;
    _emit(GameEventType.ipo, {
      'count': state.meta.ipoCount,
      'shares': gained.toDouble(),
    });
    return gained;
  }

  bool buySkill(String id) => _applyAnd(
    _engine.buySkill(state, id),
    GameEventType.buySkill,
    {'skill': id},
  );

  void collectEvent(EventConfig event, {double factor = 1}) {
    state = _engine.applyEvent(state, event, factor: factor);
    _emit(GameEventType.eventCollect, {
      'event': event.id,
      'doubled': factor > 1 ? 1 : 0,
    });
  }

  // ---------------------------------------------------------- monetization

  void addOverclock() => state = _engine.addOverclock(state);

  void turbo() => state = _engine.applyTurbo(state);

  bool timeWarp(TimeWarpConfig warp) => _applyAnd(
    _engine.timeWarp(state, warp),
    GameEventType.timeWarp,
    {'warp': warp.id},
  );

  /// Pays extra offline earnings after the "watch ad" offer.
  void addEarnings(BigNumber amount) => state = state.earn(amount);

  /// "Get it now": tops up the missing cash, then buys the line levels.
  bool buyLevelsWithGrant(int line, BuyMode mode) {
    final o = offer(line, mode);
    final missing = _engine.nearMissing(state, o.cost);
    if (missing == null || !_engine.isAvailable(state, line)) return false;
    // Top up to exactly the price: adding the difference can land a hair
    // below it through rounding.
    final topped = _engine.grantCash(state, missing);
    return _applyLevels(
      line,
      _engine.buyLevels(
        topped.cash < o.cost ? topped.copyWith(cash: o.cost) : topped,
        line,
        o.count,
      ),
    );
  }

  /// Spins the wheel; returns the prize won, or null if no spin is left.
  WheelPrize? spinWheel(
    int prizeIndex, {
    required bool free,
    required DateTime now,
  }) {
    final next = _engine.spinWheel(
      state,
      prizeIndex,
      free: free,
      nowMs: now.millisecondsSinceEpoch,
      day: dayKey(now),
    );
    if (next == null) return null;
    state = next;
    final prize = ref
        .read(economyConfigProvider)
        .monetization
        .wheel
        .prizes[prizeIndex];
    _emit(GameEventType.wheelSpin, {'prize': prize.id, 'free': free ? 1 : 0});
    return prize;
  }

  void deliverProduct(ProductConfig product) {
    final owned = _engine.ownsProduct(state, product);
    state = _engine.deliverProduct(state, product);
    if (!owned) _emit(GameEventType.purchase, {'product': product.id});
  }

  GameState? _withContract(GameState? s) =>
      s == null ? null : ref.read(questBoardProvider).ensure(s);

  /// Replaces the whole state, e.g. after offline catch-up or a reset.
  void replace(GameState next) => state = next;

  // Developer menu helpers.
  void devAddCash(BigNumber amount) => state = state.earn(amount);

  void devAddTokens() => state = state.copyWith(
    meta: state.meta.copyWith(tokens: state.meta.tokens + 100),
  );

  void devResetWheel() => state = state.copyWith(
    meta: state.meta.copyWith(lastFreeSpinMs: 0, adSpinsUsed: 0),
  );

  void devReset() => state = ref
      .read(questBoardProvider)
      .ensure(GameState.initial(ref.read(economyConfigProvider)));

  bool _applyAnd(
    GameState? next,
    GameEventType type,
    Map<String, Object> params,
  ) {
    if (!_apply(next)) return false;
    _emit(type, params);
    return true;
  }

  bool _apply(GameState? next) {
    if (next == null) return false;
    state = next;
    return true;
  }
}

/// Local calendar day as yyyymmdd, for daily limits.
int dayKey(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

/// Settings for the hidden developer menu.
class DevSettings {
  const DevSettings({this.timeScale = 1});

  final double timeScale;
}

final devSettingsProvider =
    NotifierProvider<DevSettingsController, DevSettings>(
      DevSettingsController.new,
    );

class DevSettingsController extends Notifier<DevSettings> {
  @override
  DevSettings build() => const DevSettings();

  void setTimeScale(double scale) => state = DevSettings(timeScale: scale);
}
