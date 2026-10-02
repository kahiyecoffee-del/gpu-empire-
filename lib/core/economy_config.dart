import 'big_number.dart';
import 'monetization.dart';

/// Typed view of `assets/config/economy.json`. Every balancing number lives in
/// that file; the engine reads them only through these classes.
class EconomyConfig {
  const EconomyConfig({
    required this.schemaVersion,
    required this.startingCash,
    required this.locations,
    required this.milestones,
    required this.offlineMaxSeconds,
    required this.offlineMinReportSeconds,
    required this.prestige,
    this.skills = const [],
    this.events = const EventsConfig(),
    this.contracts = const ContractsConfig(),
    this.monetization = const MonetizationConfig(),
  });

  factory EconomyConfig.fromJson(Map<String, Object?> json) {
    // Older single-location files list lines etc. at the top level.
    final locations = json['locations'] == null
        ? [
            LocationConfig.fromJson({'id': 'garage', ...json}),
          ]
        : _list(json['locations']).map(LocationConfig.fromJson).toList();
    return EconomyConfig(
      schemaVersion: _int(json['schemaVersion']),
      startingCash: BigNumber.from(_num(json['startingCash'])),
      locations: locations,
      milestones:
          _list(json['milestones']).map(MilestoneConfig.fromJson).toList()
            ..sort((a, b) => a.level.compareTo(b.level)),
      offlineMaxSeconds: _num(_map(json['offline'])['maxSeconds']).toDouble(),
      offlineMinReportSeconds: _num(
        _map(json['offline'])['minReportSeconds'] ?? 0,
      ).toDouble(),
      prestige: PrestigeConfig.fromJson(_map(json['prestige'])),
      skills: json['skills'] == null
          ? const []
          : _list(json['skills']).map(SkillConfig.fromJson).toList(),
      events: json['events'] == null
          ? const EventsConfig()
          : EventsConfig.fromJson(_map(json['events'])),
      contracts: json['contracts'] == null
          ? const ContractsConfig()
          : ContractsConfig.fromJson(_map(json['contracts'])),
      monetization: json['monetization'] == null
          ? const MonetizationConfig()
          : MonetizationConfig.fromJson(_map(json['monetization'])),
    );
  }

  final int schemaVersion;
  final BigNumber startingCash;

  /// Worlds in progression order: garage, warehouse, campus...
  final List<LocationConfig> locations;

  /// Per-line level milestones, sorted by level.
  final List<MilestoneConfig> milestones;

  /// Cap on how much time offline earnings are paid for (before skills).
  final double offlineMaxSeconds;

  /// Shorter absences are paid silently, without the welcome-back dialog.
  final double offlineMinReportSeconds;
  final PrestigeConfig prestige;

  /// Investor skills bought with shares.
  final List<SkillConfig> skills;
  final EventsConfig events;
  final ContractsConfig contracts;
  final MonetizationConfig monetization;

  SkillConfig skill(String id) => skills.firstWhere((s) => s.id == id);
}

/// One world: its own production lines, managers, upgrades and
/// infrastructure.
class LocationConfig {
  const LocationConfig({
    required this.id,
    required this.lines,
    required this.managers,
    required this.upgrades,
    required this.power,
    required this.cooling,
    this.goal,
  });

  factory LocationConfig.fromJson(Map<String, Object?> json) {
    final infra = _map(json['infrastructure']);
    return LocationConfig(
      id: json['id']! as String,
      goal: json['goal'] == null ? null : BigNumber.from(_num(json['goal'])),
      lines: _list(json['lines']).map(LineConfig.fromJson).toList(),
      managers: _list(json['managers']).map(ManagerConfig.fromJson).toList(),
      upgrades: _list(json['upgrades']).map(UpgradeConfig.fromJson).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost)),
      power: InfraConfig.fromJson(_map(infra['power'])),
      cooling: InfraConfig.fromJson(_map(infra['cooling'])),
    );
  }

  final String id;

  /// Earnings in this location needed to move to the next one. Null for the
  /// last location.
  final BigNumber? goal;

  /// Production lines in unlock order.
  final List<LineConfig> lines;
  final List<ManagerConfig> managers;

  /// Income upgrades, sorted by cost.
  final List<UpgradeConfig> upgrades;
  final InfraConfig power;
  final InfraConfig cooling;

  int lineIndex(String lineId) {
    final index = lines.indexWhere((l) => l.id == lineId);
    if (index < 0) throw ArgumentError.value(lineId, 'lineId', 'unknown line');
    return index;
  }

  bool hasLine(String lineId) => lines.any((l) => l.id == lineId);

  ManagerConfig? managerForLine(String lineId) {
    for (final m in managers) {
      if (m.lineId == lineId) return m;
    }
    return null;
  }
}

class LineConfig {
  const LineConfig({
    required this.id,
    required this.baseCost,
    required this.costGrowth,
    required this.cycleSeconds,
    required this.baseIncome,
    required this.power,
    required this.cooling,
    this.startLevel = 0,
  });

  factory LineConfig.fromJson(Map<String, Object?> json) => LineConfig(
    id: json['id']! as String,
    baseCost: _num(json['baseCost']).toDouble(),
    costGrowth: _num(json['costGrowth']).toDouble(),
    cycleSeconds: _num(json['cycleSeconds']).toDouble(),
    baseIncome: _num(json['baseIncome']).toDouble(),
    power: _num(json['power']).toDouble(),
    cooling: _num(json['cooling']).toDouble(),
    startLevel: json['startLevel'] == null ? 0 : _int(json['startLevel']),
  );

  final String id;

  /// Cost of the first level; level n costs `baseCost * costGrowth^n`.
  final double baseCost;
  final double costGrowth;

  /// Seconds for one job to complete at full efficiency.
  final double cycleSeconds;

  /// Income of one completed job per level, before multipliers.
  final double baseIncome;

  /// Power (kW) drawn per level.
  final double power;

  /// Cooling (kW of heat) needed per level.
  final double cooling;

  /// Level owned when the location starts.
  final int startLevel;
}

class MilestoneConfig {
  const MilestoneConfig({required this.level, required this.multiplier});

  factory MilestoneConfig.fromJson(Map<String, Object?> json) =>
      MilestoneConfig(
        level: _int(json['level']),
        multiplier: _num(json['multiplier']).toDouble(),
      );

  final int level;
  final double multiplier;
}

/// What a manager adds on top of automating their line.
enum ManagerBonusType {
  none,

  /// Multiplies the income of the manager's own line.
  lineIncome,

  /// Multiplies the income of every line.
  allIncome,

  /// Makes power and cooling upgrades cheaper by `value` (0.2 = 20%).
  infraDiscount,
}

class ManagerConfig {
  const ManagerConfig({
    required this.id,
    required this.lineId,
    required this.cost,
    String? role,
    this.bonus = ManagerBonusType.none,
    this.bonusValue = 0,
  }) : role = role ?? id;

  factory ManagerConfig.fromJson(Map<String, Object?> json) {
    final bonus = json['bonus'] as Map<String, Object?>?;
    return ManagerConfig(
      id: json['id']! as String,
      role: json['role'] as String?,
      lineId: json['lineId']! as String,
      cost: BigNumber.from(_num(json['cost'])),
      bonus: bonus == null
          ? ManagerBonusType.none
          : ManagerBonusType.values.byName(bonus['type']! as String),
      bonusValue: bonus == null ? 0 : _num(bonus['value']).toDouble(),
    );
  }

  final String id;

  /// Job title, used for the name and portrait (e.g. `intern`).
  final String role;
  final String lineId;
  final BigNumber cost;
  final ManagerBonusType bonus;
  final double bonusValue;
}

/// A one-time purchase that multiplies the income of one line, or of all
/// lines when [lineId] is [allLines].
class UpgradeConfig {
  const UpgradeConfig({
    required this.id,
    required this.lineId,
    required this.multiplier,
    required this.cost,
  });

  factory UpgradeConfig.fromJson(Map<String, Object?> json) => UpgradeConfig(
    id: json['id']! as String,
    lineId: json['lineId']! as String,
    multiplier: _num(json['multiplier']).toDouble(),
    cost: BigNumber.from(_num(json['cost'])),
  );

  static const allLines = 'all';

  final String id;
  final String lineId;
  final double multiplier;
  final BigNumber cost;

  bool get affectsAllLines => lineId == allLines;
}

/// A capacity resource (power or cooling) upgraded in levels.
///
/// Capacity at level L is `baseCapacity * capacityGrowth^L`; the upgrade from
/// level L costs `baseCost * costGrowth^L`.
class InfraConfig {
  const InfraConfig({
    required this.baseCapacity,
    required this.capacityGrowth,
    required this.baseCost,
    required this.costGrowth,
  });

  factory InfraConfig.fromJson(Map<String, Object?> json) => InfraConfig(
    baseCapacity: _num(json['baseCapacity']).toDouble(),
    capacityGrowth: _num(json['capacityGrowth']).toDouble(),
    baseCost: _num(json['baseCost']).toDouble(),
    costGrowth: _num(json['costGrowth']).toDouble(),
  );

  final double baseCapacity;
  final double capacityGrowth;
  final double baseCost;
  final double costGrowth;
}

/// IPO shares: `floor(k * (runEarnings / divisor) ^ exponent)`; each share
/// held adds [bonusPerShare] to all income.
class PrestigeConfig {
  const PrestigeConfig({
    required this.k,
    required this.divisor,
    required this.exponent,
    this.bonusPerShare = 0.02,
  });

  factory PrestigeConfig.fromJson(Map<String, Object?> json) => PrestigeConfig(
    k: _num(json['k']).toDouble(),
    divisor: _num(json['divisor']).toDouble(),
    exponent: _num(json['exponent']).toDouble(),
    bonusPerShare: _num(json['bonusPerShare'] ?? 0.02).toDouble(),
  );

  final double k;
  final double divisor;
  final double exponent;
  final double bonusPerShare;
}

enum SkillEffect {
  /// Multiplies all income by `value`.
  incomeMultiplier,

  /// Makes power and cooling upgrades cheaper by `value` (0.2 = 20%).
  infraDiscount,

  /// Multiplies power and cooling capacity by `value`.
  infraCapacity,

  /// Each run starts with `value` cash.
  startCash,

  /// Raises the offline earnings cap to `value` hours.
  offlineHours,

  /// Each run starts with the managers of the first `value` lines hired.
  startManagers,
}

/// An investor skill, bought once with shares.
class SkillConfig {
  const SkillConfig({
    required this.id,
    required this.branch,
    required this.cost,
    required this.effect,
    required this.value,
    this.requires,
  });

  factory SkillConfig.fromJson(Map<String, Object?> json) => SkillConfig(
    id: json['id']! as String,
    branch: json['branch']! as String,
    cost: BigNumber.from(_num(json['cost'])),
    effect: SkillEffect.values.byName(json['effect']! as String),
    value: _num(json['value']).toDouble(),
    requires: json['requires'] as String?,
  );

  final String id;

  /// Column in the tree: `income`, `infra` or `automation`.
  final String branch;

  /// Shares spent (and so no longer counted for the share bonus).
  final BigNumber cost;
  final SkillEffect effect;
  final double value;

  /// Skill that must be owned first.
  final String? requires;
}

enum EventKind {
  /// Multiplies income by `value` for `seconds`.
  boost,

  /// Pays `value` seconds of full-speed income at once.
  cash,
}

class EventConfig {
  const EventConfig({
    required this.id,
    required this.kind,
    required this.value,
    this.seconds = 0,
    this.weight = 1,
  });

  factory EventConfig.fromJson(Map<String, Object?> json) => EventConfig(
    id: json['id']! as String,
    kind: EventKind.values.byName(json['kind']! as String),
    value: _num(json['value']).toDouble(),
    seconds: _num(json['seconds'] ?? 0).toDouble(),
    weight: _num(json['weight'] ?? 1).toDouble(),
  );

  final String id;
  final EventKind kind;
  final double value;
  final double seconds;

  /// Relative chance of being picked.
  final double weight;
}

/// Random events: one appears every [minInterval]–[maxInterval] seconds of
/// play and waits [lifetime] seconds to be tapped.
class EventsConfig {
  const EventsConfig({
    this.minInterval = 180,
    this.maxInterval = 300,
    this.lifetime = 25,
    this.list = const [],
  });

  factory EventsConfig.fromJson(Map<String, Object?> json) => EventsConfig(
    minInterval: _num(json['minInterval']).toDouble(),
    maxInterval: _num(json['maxInterval']).toDouble(),
    lifetime: _num(json['lifetime']).toDouble(),
    list: _list(json['list']).map(EventConfig.fromJson).toList(),
  );

  final double minInterval;
  final double maxInterval;
  final double lifetime;
  final List<EventConfig> list;
}

/// Generated per-run contracts: reward is [rewardFraction] of this run's
/// earnings.
class ContractsConfig {
  const ContractsConfig({this.rewardFraction = 0.03, this.levelStep = 10});

  factory ContractsConfig.fromJson(Map<String, Object?> json) =>
      ContractsConfig(
        rewardFraction: _num(json['rewardFraction']).toDouble(),
        levelStep: _int(json['levelStep']),
      );

  final double rewardFraction;

  /// Level contracts ask for at least this many more levels.
  final int levelStep;
}

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

Iterable<Map<String, Object?>> _list(Object? value) =>
    (value! as List<Object?>).cast<Map<String, Object?>>();

num _num(Object? value) => value! as num;

int _int(Object? value) => (value! as num).toInt();
