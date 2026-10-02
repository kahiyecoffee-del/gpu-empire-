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

  LocationConfig location(GameState s) => config.locations[s.locationIndex];

  LineConfig lineConfig(GameState s, int line) => location(s).lines[line];

  // ---------------------------------------------------------------- lines

  /// A line can be bought once the previous line is unlocked.
  bool isAvailable(GameState s, int line) =>
      line == 0 || s.lines[line - 1].isUnlocked;

  ManagerConfig? managerFor(GameState s, int line) =>
      location(s).managerForLine(lineConfig(s, line).id);

  bool hasManager(GameState s, int line) {
    final manager = managerFor(s, line);
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
    final id = lineConfig(s, line).id;
    var multiplier = 1.0;
    for (final u in location(s).upgrades) {
      if ((u.affectsAllLines || u.lineId == id) && s.upgrades.contains(u.id)) {
        multiplier *= u.multiplier;
      }
    }
    return multiplier;
  }

  /// Income multiplier from hired managers' bonuses for [line].
  double managerMultiplier(GameState s, int line) {
    final id = lineConfig(s, line).id;
    var multiplier = 1.0;
    for (final m in location(s).managers) {
      if (!s.managers.contains(m.id)) continue;
      if (m.bonus == ManagerBonusType.allIncome ||
          (m.bonus == ManagerBonusType.lineIncome && m.lineId == id)) {
        multiplier *= m.bonusValue;
      }
    }
    return multiplier;
  }

  /// Product of all owned skills with [effect] (1 if none).
  double skillProduct(GameState s, SkillEffect effect) {
    var product = 1.0;
    for (final id in s.meta.skills) {
      final skill = config.skill(id);
      if (skill.effect == effect) product *= skill.value;
    }
    return product;
  }

  /// Largest value among owned skills with [effect], or null.
  double? skillMax(GameState s, SkillEffect effect) {
    double? best;
    for (final id in s.meta.skills) {
      final skill = config.skill(id);
      if (skill.effect == effect && (best == null || skill.value > best)) {
        best = skill.value;
      }
    }
    return best;
  }

  /// Income bonus from unspent shares: `1 + shares * bonusPerShare`.
  BigNumber shareMultiplier(GameState s) =>
      BigNumber.one + s.meta.shares.scale(config.prestige.bonusPerShare);

  double boostMultiplier(GameState s) => s.boost?.multiplier ?? 1;

  /// Income of one completed job on [line].
  BigNumber incomePerJob(GameState s, int line) {
    final level = s.lines[line].level;
    if (level == 0) return BigNumber.zero;
    final c = lineConfig(s, line);
    final multipliers =
        milestoneMultiplier(level) *
        upgradeMultiplier(s, line) *
        managerMultiplier(s, line) *
        skillProduct(s, SkillEffect.incomeMultiplier) *
        boostMultiplier(s);
    return BigNumber.from(c.baseIncome * level * multipliers) *
        shareMultiplier(s);
  }

  /// Seconds per job at the current efficiency.
  double effectiveCycleSeconds(GameState s, int line) =>
      lineConfig(s, line).cycleSeconds / efficiency(s);

  /// Income per second of [line] if it runs continuously.
  BigNumber lineRate(GameState s, int line) => incomePerJob(
    s,
    line,
  ).scale(efficiency(s) / lineConfig(s, line).cycleSeconds);

  /// Income per second if every unlocked line ran continuously.
  BigNumber fullRate(GameState s) {
    var total = BigNumber.zero;
    for (var i = 0; i < s.lines.length; i++) {
      total += lineRate(s, i);
    }
    return total;
  }

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
    final c = lineConfig(s, line);
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
    final c = lineConfig(s, line);
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

  InfraConfig infraConfig(GameState s, InfraKind kind) =>
      kind == InfraKind.power ? location(s).power : location(s).cooling;

  int infraLevel(GameState s, InfraKind kind) =>
      kind == InfraKind.power ? s.powerLevel : s.coolingLevel;

  double capacity(GameState s, InfraKind kind) {
    final c = infraConfig(s, kind);
    return c.baseCapacity *
        math.pow(c.capacityGrowth, infraLevel(s, kind)).toDouble() *
        skillProduct(s, SkillEffect.infraCapacity);
  }

  double demand(GameState s, InfraKind kind) {
    var total = 0.0;
    for (var i = 0; i < s.lines.length; i++) {
      final c = lineConfig(s, i);
      total +=
          s.lines[i].level * (kind == InfraKind.power ? c.power : c.cooling);
    }
    return total;
  }

  /// Price factor for infrastructure after manager and skill discounts.
  double infraPriceFactor(GameState s) {
    var factor = 1.0;
    for (final m in location(s).managers) {
      if (m.bonus == ManagerBonusType.infraDiscount &&
          s.managers.contains(m.id)) {
        factor *= 1 - m.bonusValue;
      }
    }
    for (final id in s.meta.skills) {
      final skill = config.skill(id);
      if (skill.effect == SkillEffect.infraDiscount) factor *= 1 - skill.value;
    }
    return factor;
  }

  BigNumber infraCost(GameState s, InfraKind kind) {
    final c = infraConfig(s, kind);
    final logG = math.log(c.costGrowth) / math.ln10;
    return BigNumber.fromLog10(infraLevel(s, kind) * logG)
        .scale(c.baseCost * infraPriceFactor(s));
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

  /// Offline earnings cap in seconds, raised by skills.
  double offlineCapSeconds(GameState s) {
    final hours = skillMax(s, SkillEffect.offlineHours);
    final skillCap = hours == null ? 0.0 : hours * 3600;
    return math.max(config.offlineMaxSeconds, skillCap);
  }

  // ------------------------------------------------------------ locations

  LocationConfig? nextLocation(GameState s) =>
      s.locationIndex + 1 < config.locations.length
      ? config.locations[s.locationIndex + 1]
      : null;

  /// Progress towards the current location's goal, 0..1.
  double locationProgress(GameState s) {
    final goal = location(s).goal;
    if (goal == null) return 0;
    final p = (s.locationEarned / goal).toDouble();
    return p.clamp(0.0, 1.0);
  }

  bool canMove(GameState s) {
    final goal = location(s).goal;
    return goal != null && nextLocation(s) != null && s.locationEarned >= goal;
  }

  /// Moves to the next location: cash, lines, managers, upgrades and
  /// infrastructure start fresh there. Null if the goal is not reached.
  GameState? moveToNextLocation(GameState s) {
    final next = nextLocation(s);
    if (next == null || !canMove(s)) return null;
    return GameState(
      cash: config.startingCash,
      totalEarned: s.totalEarned,
      locationIndex: s.locationIndex + 1,
      locationEarned: BigNumber.zero,
      lines: GameState.freshLines(next),
      playSeconds: s.playSeconds,
      manualJobs: s.manualJobs,
      contractIndex: s.contractIndex,
      boost: s.boost,
      meta: s.meta,
    );
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

  bool canIpo(GameState s) => sharesPreview(s) >= BigNumber.one;

  /// Goes public: everything but [MetaState] resets, and the run's shares
  /// are added. Null if the IPO would pay no shares.
  GameState? ipo(GameState s) {
    final gained = sharesPreview(s);
    if (gained < BigNumber.one) return null;
    final meta = s.meta.copyWith(
      shares: s.meta.shares + gained,
      ipoCount: s.meta.ipoCount + 1,
    );
    return newRun(meta);
  }

  /// A fresh run for [meta], with start-of-run skills applied.
  GameState newRun(MetaState meta) {
    var state = GameState.initial(config, meta: meta);
    final startCash = skillMax(state, SkillEffect.startCash);
    if (startCash != null) {
      state = state.copyWith(cash: BigNumber.from(startCash));
    }
    final startManagers = skillMax(state, SkillEffect.startManagers);
    if (startManagers != null) {
      final loc = location(state);
      final hired = <String>{
        for (var i = 0; i < startManagers.toInt() && i < loc.lines.length; i++)
          ?loc.managerForLine(loc.lines[i].id)?.id,
      };
      state = state.copyWith(managers: hired);
    }
    return state;
  }

  bool canBuySkill(GameState s, SkillConfig skill) =>
      !s.meta.skills.contains(skill.id) &&
      (skill.requires == null || s.meta.skills.contains(skill.requires)) &&
      s.meta.shares >= skill.cost;

  GameState? buySkill(GameState s, String skillId) {
    final skill = config.skill(skillId);
    if (!canBuySkill(s, skill)) return null;
    return s.copyWith(
      meta: s.meta.copyWith(
        shares: s.meta.shares - skill.cost,
        skills: {...s.meta.skills, skillId},
      ),
    );
  }

  // ---------------------------------------------------------------- events

  /// Applies a collected random event.
  GameState applyEvent(GameState s, EventConfig event) => switch (event.kind) {
    EventKind.boost => s.copyWith(
      boost: Boost(multiplier: event.value, secondsLeft: event.seconds),
    ),
    EventKind.cash => s.earn(fullRate(s).scale(event.value)),
  };

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
    final loc = location(s);
    final manager = loc.managers.where((m) => m.id == managerId).firstOrNull;
    if (manager == null) return null;
    final line = loc.lineIndex(manager.lineId);
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
          s.lines[location(s).lineIndex(upgrade.lineId)].isUnlocked);

  GameState? buyUpgrade(GameState s, String upgradeId) {
    final upgrade = location(s).upgrades
        .where((u) => u.id == upgradeId)
        .firstOrNull;
    if (upgrade == null ||
        !isUpgradeAvailable(s, upgrade) ||
        upgrade.cost > s.cash) {
      return null;
    }
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
    // A boost that ends mid-tick only applies to its remaining seconds.
    final boost = s.boost;
    if (boost != null && dt > boost.secondsLeft) {
      final boosted = _advance(s, boost.secondsLeft, countPlayTime);
      return _advance(
        boosted.copyWith(clearBoost: true),
        dt - boost.secondsLeft,
        countPlayTime,
      );
    }
    final next = _advance(s, dt, countPlayTime);
    if (boost == null) return next;
    final left = boost.secondsLeft - dt;
    return left <= 0
        ? next.copyWith(clearBoost: true)
        : next.copyWith(
            boost: Boost(multiplier: boost.multiplier, secondsLeft: left),
          );
  }

  GameState _advance(GameState s, double dt, bool countPlayTime) {
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
      final cycle = lineConfig(s, i).cycleSeconds;
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
    final next = earned.isZero ? s : s.earn(earned);
    return next.copyWith(
      lines: lines,
      playSeconds: countPlayTime ? s.playSeconds + dt : null,
      manualJobs: manualJobs > 0 ? s.manualJobs + manualJobs : null,
    );
  }
}
