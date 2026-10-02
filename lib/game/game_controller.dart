import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/big_number.dart';
import '../core/economy_config.dart';
import '../core/economy_engine.dart';
import '../core/game_state.dart';
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
  GameState build() =>
      ref.watch(initialGameStateProvider) ??
      GameState.initial(ref.watch(economyConfigProvider));

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

  /// Collects the finished side quest. Returns the reward, or null if the
  /// active quest is not done yet.
  BigNumber? claimQuest() {
    final book = ref.read(questBookProvider);
    final quest = book.current(state);
    if (quest == null) return null;
    final reward = book.reward(state, quest);
    final next = book.claim(state);
    if (next == null) return null;
    state = next;
    return reward;
  }

  /// Replaces the whole state, e.g. after offline catch-up or a reset.
  void replace(GameState next) => state = next;

  // Developer menu helpers.
  void devAddCash(BigNumber amount) => state = state.copyWith(
    cash: state.cash + amount,
    totalEarned: state.totalEarned + amount,
  );

  void devReset() => state = GameState.initial(ref.read(economyConfigProvider));

  bool _apply(GameState? next) {
    if (next == null) return false;
    state = next;
    return true;
  }
}

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
