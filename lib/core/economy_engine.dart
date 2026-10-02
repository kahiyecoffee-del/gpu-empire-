import 'dart:math' as math;

import 'big_number.dart';
import 'economy_config.dart';
import 'game_state.dart';

enum InfraKind { power, cooling }

/// Pure economy rules. Every method is a function of (config, state) with no
/// side effects, so the UI, the save system and the simulator share one
/// source of truth and the rules are easy to test.
class EconomyEngine {
  const EconomyEngine(this.config);

  final EconomyConfig config;

  // ---------------------------------------------------------------- lines

  /// A line can be bought once the previous line is unlocked.
  bool isAvailable(GameState s, int line) =>
      line == 0 || s.lines[line - 1].isUnlocked;

  bool hasManager(GameState s, int line) {
    final manager = config.managerForLine(config.lines[line].id);
    return manager != null && s.managers.contains(manager.id);
  }

  /// Product of all milestone multipliers reached at [level].
  double milestoneMultiplier(int level) {
    var multiplier = 1.0;
    for (final m in config.milestones) {
      if (level < m.level) break;
      multiplier *= m.multiplier;
    }
    return multiplier;
  }

  /// The next milestone above [level], or null when all are reached.
  MilestoneConfig? nextMilestone(int level) {
    for (final m in config.milestones) {
      if (m.level > level) return m;
    }
    return null;
  }

  /// Product of the multipliers of all bought upgrades that affect [line].
  double upgradeMultiplier(GameState s, int line) {
    final id = config.lines[line].id;
    var multiplier = 1.0;
    for (final u in config.upgrades) {
      if ((u.affectsAllLines || u.lineId == id) && s.upgrades.contains(u.id)) {
        multiplier *= u.multiplier;
      }
    }
    return multiplier;
  }

  /// Income of one completed job on [line].
  BigNumber incomePerJob(GameState s, int line) {
    final level = s.lines[line].level;
    if (level == 0) return BigNumber.zero;
    final c = config.lines[line];
    return BigNumber.from(c.baseIncome * level * milestoneMultiplier(level))
        .scale(upgradeMultiplier(s, line));
  }

  /// Seconds per job at the current efficiency.
  double effectiveCycleSeconds(GameState s, int line) =>
      config.lines[line].cycleSeconds / efficiency(s);

  /// Income per second of [line] if it runs continuously.
  BigNumber lineRate(GameState s, int line) => incomePerJob(
    s,
    line,
  ).scale(efficiency(s) / config.lines[line].cycleSeconds);

  /// Income per second from lines that run on their own (managed lines).
  BigNumber passiveIncomePerSecond(GameState s) {
    var total = BigNumber.zero;
    for (var i = 0; i < s.lines.length; i++) {
      if (hasManager(s, i)) total += lineRate(s, i);
    }
    return total;
  }

  /// Cost of buying [count] levels of [line] starting from the current level.
  ///
  /// Geometric series: `base * g^n * (g^count - 1) / (g - 1)`.
  BigNumber levelCost(GameState s, int line, int count) {
    final c = config.lines[line];
    final owned = s.lines[line].level;
    final logG = math.log(c.costGrowth) / math.ln10;
    final start = BigNumber.fromLog10(owned * logG).scale(c.baseCost);
    final series = (BigNumber.fromLog10(count * logG) - BigNumber.one).scale(
      1 / (c.costGrowth - 1),
    );
    return start * series;
  }

  /// Most levels of [line] affordable with the current cash.
  int maxAffordable(GameState s, int line) {
    if (!isAvailable(s, line)) return 0;
    final c = config.lines[line];
    final owned = s.lines[line].level;
    final logG = math.log(c.costGrowth) / math.ln10;
    final start = BigNumber.fromLog10(owned * logG).scale(c.baseCost);
    // Solve cash = start * (g^k - 1) / (g - 1) for k.
    final ratio = s.cash.scale(c.costGrowth - 1) / start + BigNumber.one;
    var k = (ratio.log10() / logG).floor();
    if (k < 0) k = 0;
    // Guard against floating error at the boundary.
    while (k > 0 && levelCost(s, line, k) > s.cash) {
      k--;
    }
    return k;
  }

  // -------------------------------------------------------- infrastructure

  InfraConfig infraConfig(InfraKind kind) =>
      kind == InfraKind.power ? config.power : config.cooling;

  int infraLevel(GameState s, InfraKind kind) =>
      kind == InfraKind.power ? s.powerLevel : s.coolingLevel;

  double capacity(GameState s, InfraKind kind) {
    final c = infraConfig(kind);
    return c.baseCapacity *
        math.pow(c.capacityGrowth, infraLevel(s, kind)).toDouble();
  }

  double demand(GameState s, InfraKind kind) {
    var total = 0.0;
    for (var i = 0; i < s.lines.length; i++) {
      final c = config.lines[i];
      total +=
          s.lines[i].level * (kind == InfraKind.power ? c.power : c.cooling);
    }
    return total;
  }

  BigNumber infraCost(GameState s, InfraKind kind) {
    final c = infraConfig(kind);
    final logG = math.log(c.costGrowth) / math.ln10;
    return BigNumber.fromLog10(infraLevel(s, kind) * logG).scale(c.baseCost);
  }

  /// Load factor of one resource: 1.0 means demand equals capacity.
  double load(GameState s, InfraKind kind) =>
      demand(s, kind) / capacity(s, kind);

  /// Production speed multiplier from the soft throttle:
  /// `min(1, capacity / demand)` for the scarcer of power and cooling.
  double efficiency(GameState s) {
    final worstLoad = math.max(
      load(s, InfraKind.power),
      load(s, InfraKind.cooling),
    );
    return worstLoad <= 1 ? 1 : 1 / worstLoad;
  }

  // ------------------------------------------------------------- prestige

  /// Shares an IPO would pay right now.
  BigNumber sharesPreview(GameState s) {
    final p = config.prestige;
    if (s.totalEarned.isZero) return BigNumber.zero;
    return (s.totalEarned.scale(1 / p.divisor).pow(p.exponent))
        .scale(p.k)
        .floor();
  }

  // -------------------------------------------------------------- actions

  /// Starts a job on an idle, unmanaged line. No-op otherwise.
  GameState tap(GameState s, int line) {
    final l = s.lines[line];
    if (!l.isUnlocked || l.running || hasManager(s, line)) return s;
    return s.withLine(line, l.copyWith(running: true));
  }

  /// Buys [count] levels of [line]. Returns null if not possible.
  GameState? buyLevels(GameState s, int line, int count) {
    if (count <= 0 || !isAvailable(s, line)) return null;
    final cost = levelCost(s, line, count);
    if (cost > s.cash) return null;
    final l = s.lines[line];
    return s
        .withLine(line, l.copyWith(level: l.level + count))
        .copyWith(cash: s.cash - cost);
  }

  GameState? buyManager(GameState s, String managerId) {
    final manager = config.managers.firstWhere((m) => m.id == managerId);
    final line = config.lineIndex(manager.lineId);
    if (s.managers.contains(managerId) ||
        !s.lines[line].isUnlocked ||
        manager.cost > s.cash) {
      return null;
    }
    // A managed line keeps whatever progress the manual job had.
    return s.copyWith(
      cash: s.cash - manager.cost,
      managers: {...s.managers, managerId},
    );
  }

  /// Whether [upgrade] can be shown to the player: not bought yet and its
  /// line is unlocked.
  bool isUpgradeAvailable(GameState s, UpgradeConfig upgrade) =>
      !s.upgrades.contains(upgrade.id) &&
      (upgrade.affectsAllLines ||
          s.lines[config.lineIndex(upgrade.lineId)].isUnlocked);

  GameState? buyUpgrade(GameState s, String upgradeId) {
    final upgrade = config.upgrades.firstWhere((u) => u.id == upgradeId);
    if (!isUpgradeAvailable(s, upgrade) || upgrade.cost > s.cash) return null;
    return s.copyWith(
      cash: s.cash - upgrade.cost,
      upgrades: {...s.upgrades, upgradeId},
    );
  }

  GameState? buyInfra(GameState s, InfraKind kind) {
    final cost = infraCost(s, kind);
    if (cost > s.cash) return null;
    return s.copyWith(
      cash: s.cash - cost,
      powerLevel: kind == InfraKind.power ? s.powerLevel + 1 : null,
      coolingLevel: kind == InfraKind.cooling ? s.coolingLevel + 1 : null,
    );
  }

  // ----------------------------------------------------------------- time

  /// Advances the simulation by [dt] seconds.
  ///
  /// Managed lines complete as many jobs as fit in [dt], so this is exact for
  /// long offline periods too. Manual lines complete at most one job and then
  /// wait for the next tap. Offline catch-up passes [countPlayTime] false.
  GameState tick(GameState s, double dt, {bool countPlayTime = true}) {
    if (dt <= 0) return s;
    final speed = efficiency(s);
    var earned = BigNumber.zero;
    var manualJobs = 0;
    List<LineState>? lines;
    for (var i = 0; i < s.lines.length; i++) {
      final l = s.lines[i];
      if (!l.isUnlocked) continue;
      final managed = hasManager(s, i);
      if (!managed && !l.running) continue;
      final cycle = config.lines[i].cycleSeconds;
      var progress = l.progress + dt * speed;
      var running = l.running;
      if (managed) {
        final jobs = (progress / cycle).floorToDouble();
        if (jobs > 0) {
          earned += incomePerJob(s, i).scale(jobs);
          progress -= jobs * cycle;
        }
      } else if (progress >= cycle) {
        earned += incomePerJob(s, i);
        progress = 0;
        running = false;
        manualJobs++;
      }
      lines ??= [...s.lines];
      lines[i] = l.copyWith(progress: progress, running: running);
    }
    return s.copyWith(
      cash: s.cash + earned,
      totalEarned: s.totalEarned + earned,
      lines: lines,
      playSeconds: countPlayTime ? s.playSeconds + dt : null,
      manualJobs: manualJobs > 0 ? s.manualJobs + manualJobs : null,
    );
  }
}
