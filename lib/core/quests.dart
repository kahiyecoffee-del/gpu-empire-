import 'big_number.dart';
import 'economy_engine.dart';
import 'game_state.dart';

/// What a quest asks the player to do.
enum QuestType {
  /// Complete [QuestConfig.amount] jobs by tapping.
  manualJobs,

  /// Get line [QuestConfig.target] to level [QuestConfig.amount].
  lineLevel,

  /// Get every line to level [QuestConfig.amount].
  allLinesLevel,

  /// Hire manager [QuestConfig.target].
  hireManager,

  /// Own [QuestConfig.amount] income upgrades.
  upgrades,

  /// Get infrastructure [QuestConfig.target] (`power` or `cooling`) to
  /// level [QuestConfig.amount].
  infraLevel,

  /// Earn [QuestConfig.amount] in total this run.
  totalEarned,
}

/// One side quest from `assets/config/quests.json`. Its texts live in the
/// translation files under the quest id.
class QuestConfig {
  const QuestConfig({
    required this.id,
    required this.type,
    required this.amount,
    required this.rewardFraction,
    required this.minReward,
    this.target,
  });

  factory QuestConfig.fromJson(Map<String, Object?> json) => QuestConfig(
    id: json['id']! as String,
    type: QuestType.values.byName(json['type']! as String),
    target: json['target'] as String?,
    amount: (json['amount']! as num).toDouble(),
    rewardFraction: (json['rewardFraction']! as num).toDouble(),
    minReward: BigNumber.from(json['minReward']! as num),
  );

  final String id;
  final QuestType type;

  /// Line id, manager id or infrastructure kind, depending on [type].
  final String? target;
  final double amount;

  /// The cash reward is this share of everything earned this run, so it
  /// keeps pace with the economy without snowballing...
  final double rewardFraction;

  /// ...but never less than this, so early rewards still feel good.
  final BigNumber minReward;
}

/// Progress towards a quest goal.
class QuestProgress {
  const QuestProgress(this.current, this.goal);

  final double current;
  final double goal;

  bool get isComplete => current >= goal;
  double get fraction => goal <= 0 ? 1 : (current / goal).clamp(0.0, 1.0);
}

/// Quest rules: the advisor hands out [quests] one at a time, in order.
class QuestBook {
  const QuestBook(this.engine, this.quests);

  final EconomyEngine engine;
  final List<QuestConfig> quests;

  static List<QuestConfig> parse(Map<String, Object?> json) =>
      (json['quests']! as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(QuestConfig.fromJson)
          .toList();

  /// The active quest, or null once all are done.
  QuestConfig? current(GameState s) =>
      s.questIndex < quests.length ? quests[s.questIndex] : null;

  QuestProgress progress(GameState s, QuestConfig q) {
    final config = engine.config;
    final current = switch (q.type) {
      QuestType.manualJobs => s.manualJobs.toDouble(),
      QuestType.lineLevel =>
        s.lines[config.lineIndex(q.target!)].level.toDouble(),
      QuestType.allLinesLevel =>
        s.lines.map((l) => l.level).reduce((a, b) => a < b ? a : b).toDouble(),
      QuestType.hireManager => s.managers.contains(q.target) ? 1.0 : 0.0,
      QuestType.upgrades => s.upgrades.length.toDouble(),
      QuestType.infraLevel =>
        engine.infraLevel(s, InfraKind.values.byName(q.target!)).toDouble(),
      QuestType.totalEarned => s.totalEarned.toDouble(),
    };
    final goal = q.type == QuestType.hireManager ? 1.0 : q.amount;
    return QuestProgress(current, goal);
  }

  /// Cash the active quest pays right now.
  BigNumber reward(GameState s, QuestConfig q) =>
      s.totalEarned.scale(q.rewardFraction).max(q.minReward);

  /// Pays the active quest and moves on. Null if it is not complete.
  GameState? claim(GameState s) {
    final q = current(s);
    if (q == null || !progress(s, q).isComplete) return null;
    final paid = reward(s, q);
    return s.copyWith(
      cash: s.cash + paid,
      totalEarned: s.totalEarned + paid,
      questIndex: s.questIndex + 1,
    );
  }
}
