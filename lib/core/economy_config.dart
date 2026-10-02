import 'big_number.dart';

/// Typed view of `assets/config/economy.json`. Every balancing number lives in
/// that file; the engine reads them only through these classes.
class EconomyConfig {
  const EconomyConfig({
    required this.schemaVersion,
    required this.startingCash,
    required this.lines,
    required this.milestones,
    required this.managers,
    required this.upgrades,
    required this.power,
    required this.cooling,
    required this.offlineMaxSeconds,
    required this.offlineMinReportSeconds,
    required this.prestige,
  });

  factory EconomyConfig.fromJson(Map<String, Object?> json) {
    final infra = _map(json['infrastructure']);
    return EconomyConfig(
      schemaVersion: _int(json['schemaVersion']),
      startingCash: BigNumber.from(_num(json['startingCash'])),
      lines: _list(json['lines']).map(LineConfig.fromJson).toList(),
      milestones:
          _list(json['milestones']).map(MilestoneConfig.fromJson).toList()
            ..sort((a, b) => a.level.compareTo(b.level)),
      managers: _list(json['managers']).map(ManagerConfig.fromJson).toList(),
      upgrades: _list(json['upgrades']).map(UpgradeConfig.fromJson).toList()
        ..sort((a, b) => a.cost.compareTo(b.cost)),
      power: InfraConfig.fromJson(_map(infra['power'])),
      cooling: InfraConfig.fromJson(_map(infra['cooling'])),
      offlineMaxSeconds: _num(_map(json['offline'])['maxSeconds']).toDouble(),
      offlineMinReportSeconds: _num(
        _map(json['offline'])['minReportSeconds'] ?? 0,
      ).toDouble(),
      prestige: PrestigeConfig.fromJson(_map(json['prestige'])),
    );
  }

  final int schemaVersion;
  final BigNumber startingCash;

  /// Production lines in unlock order.
  final List<LineConfig> lines;

  /// Per-line level milestones, sorted by level.
  final List<MilestoneConfig> milestones;
  final List<ManagerConfig> managers;

  /// Income upgrades, sorted by cost.
  final List<UpgradeConfig> upgrades;
  final InfraConfig power;
  final InfraConfig cooling;

  /// Cap on how much time offline earnings are paid for.
  final double offlineMaxSeconds;

  /// Shorter absences are paid silently, without the welcome-back dialog.
  final double offlineMinReportSeconds;
  final PrestigeConfig prestige;

  int lineIndex(String lineId) {
    final index = lines.indexWhere((l) => l.id == lineId);
    if (index < 0) throw ArgumentError.value(lineId, 'lineId', 'unknown line');
    return index;
  }

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

  /// Level owned at the start of a new game.
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

class ManagerConfig {
  const ManagerConfig({
    required this.id,
    required this.lineId,
    required this.cost,
  });

  factory ManagerConfig.fromJson(Map<String, Object?> json) => ManagerConfig(
    id: json['id']! as String,
    lineId: json['lineId']! as String,
    cost: BigNumber.from(_num(json['cost'])),
  );

  final String id;
  final String lineId;
  final BigNumber cost;
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

/// IPO shares: `floor(k * (totalEarned / divisor) ^ exponent)`.
class PrestigeConfig {
  const PrestigeConfig({
    required this.k,
    required this.divisor,
    required this.exponent,
  });

  factory PrestigeConfig.fromJson(Map<String, Object?> json) => PrestigeConfig(
    k: _num(json['k']).toDouble(),
    divisor: _num(json['divisor']).toDouble(),
    exponent: _num(json['exponent']).toDouble(),
  );

  final double k;
  final double divisor;
  final double exponent;
}

Map<String, Object?> _map(Object? value) => value! as Map<String, Object?>;

Iterable<Map<String, Object?>> _list(Object? value) =>
    (value! as List<Object?>).cast<Map<String, Object?>>();

num _num(Object? value) => value! as num;

int _int(Object? value) => (value! as num).toInt();
