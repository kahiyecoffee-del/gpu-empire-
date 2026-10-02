import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big_number.dart';
import '../core/economy_config.dart';
import '../core/economy_engine.dart';
import '../core/game_state.dart';
import '../core/monetization.dart';
import '../core/quests.dart';

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

  @override
  GameState build() => ref
      .read(questBoardProvider)
      .ensure(
        ref.watch(initialGameStateProvider) ??
            GameState.initial(ref.watch(economyConfigProvider)),
      );

  void tick(double dt) => state = _engine.tick(state, dt);

  void tap(int line) => state = _engine.tap(state, line);

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
  bool buyLevels(int line, BuyMode mode) =>
      _apply(_engine.buyLevels(state, line, offer(line, mode).count));

  bool buyManager(String id) => _apply(_engine.buyManager(state, id));

  bool buyUpgrade(String id) => _apply(_engine.buyUpgrade(state, id));

  bool buyInfra(InfraKind kind) => _apply(_engine.buyInfra(state, kind));

  /// Collects the quest Max is showing. Returns the reward, or null if it
  /// is not done yet.
  BigNumber? claimQuest({double factor = 1}) {
    final board = ref.read(questBoardProvider);
    final (quest, _) = board.active(state);
    final reward = board.reward(state, quest).scale(factor);
    final next = board.claim(state, factor: factor);
    if (next == null) return null;
    state = board.ensure(next);
    return reward;
  }

  bool moveToNextLocation() =>
      _apply(_withContract(_engine.moveToNextLocation(state)));

  /// Goes public. Returns the shares gained, or null if none.
  BigNumber? goPublic() {
    final gained = _engine.sharesPreview(state);
    final next = _withContract(_engine.ipo(state));
    if (next == null) return null;
    state = next;
    return gained;
  }

  bool buySkill(String id) => _apply(_engine.buySkill(state, id));

  void collectEvent(EventConfig event, {double factor = 1}) =>
      state = _engine.applyEvent(state, event, factor: factor);

  // ---------------------------------------------------------- monetization

  void addOverclock() => state = _engine.addOverclock(state);

  void turbo() => state = _engine.applyTurbo(state);

  bool timeWarp(TimeWarpConfig warp) => _apply(_engine.timeWarp(state, warp));

  /// Pays extra offline earnings after the "watch ad" offer.
  void addEarnings(BigNumber amount) => state = state.earn(amount);

  /// "Get it now": tops up the missing cash, then buys the line levels.
  bool buyLevelsWithGrant(int line, BuyMode mode) {
    final o = offer(line, mode);
    final missing = _engine.nearMissing(state, o.cost);
    if (missing == null || !_engine.isAvailable(state, line)) return false;
    return _apply(
      _engine.buyLevels(_engine.grantCash(state, missing), line, o.count),
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
    return ref
        .read(economyConfigProvider)
        .monetization
        .wheel
        .prizes[prizeIndex];
  }

  void deliverProduct(ProductConfig product) =>
      state = _engine.deliverProduct(state, product);

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
