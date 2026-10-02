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
  BigNumber? claimQuest() {
    final board = ref.read(questBoardProvider);
    final (quest, _) = board.active(state);
    final reward = board.reward(state, quest);
    final next = board.claim(state);
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

  void collectEvent(EventConfig event) =>
      state = _engine.applyEvent(state, event);

  GameState? _withContract(GameState? s) =>
      s == null ? null : ref.read(questBoardProvider).ensure(s);

  /// Replaces the whole state, e.g. after offline catch-up or a reset.
  void replace(GameState next) => state = next;

  // Developer menu helpers.
  void devAddCash(BigNumber amount) => state = state.earn(amount);

  void devReset() => state = ref
      .read(questBoardProvider)
      .ensure(GameState.initial(ref.read(economyConfigProvider)));

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
