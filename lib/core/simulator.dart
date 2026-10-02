import 'big_number.dart';
import 'economy_engine.dart';
import 'game_state.dart';

/// How the simulated player behaves. These describe the bot, not the game,
/// so they live here rather than in economy.json.
class SimSettings {
  const SimSettings({
    this.step = 0.1,
    this.tapInterval = 0.5,
    this.decisionInterval = 1.0,
    this.snapshotInterval = 60,
  });

  /// Simulation time step in seconds.
  final double step;

  /// Seconds between two taps: a focused human taps about twice a second.
  final double tapInterval;

  /// Seconds between purchase decisions.
  final double decisionInterval;

  /// Seconds between recorded snapshots.
  final double snapshotInterval;
}

enum SimEventKind { purchase, lineUnlocked, manager, upgrade, infra }

class SimEvent {
  const SimEvent(this.time, this.kind, this.label, this.cost);

  final double time;
  final SimEventKind kind;
  final String label;
  final BigNumber cost;
}

class SimSnapshot {
  const SimSnapshot({
    required this.time,
    required this.state,
    required this.estimatedRate,
    required this.efficiency,
    required this.shares,
  });

  final double time;
  final GameState state;
  final BigNumber estimatedRate;
  final double efficiency;
  final BigNumber shares;
}

class SimResult {
  const SimResult({
    required this.events,
    required this.idleStretches,
    required this.snapshots,
    required this.finalState,
    required this.duration,
  });

  final List<SimEvent> events;

  /// Periods (start, end) in which no useful purchase was affordable: the
  /// "nothing to do" feeling the pacing targets limit.
  final List<(double, double)> idleStretches;
  final List<SimSnapshot> snapshots;
  final GameState finalState;
  final double duration;

  Iterable<double> get purchaseTimes => events.map((e) => e.time);

  BigNumber get totalSpent =>
      events.fold(BigNumber.zero, (sum, e) => sum + e.cost);

  double? get firstPurchase => events.isEmpty ? null : events.first.time;

  /// Time at which line [index] was first bought, or null.
  double? lineUnlockTime(String lineId) {
    for (final e in events) {
      if (e.kind == SimEventKind.lineUnlocked && e.label == lineId) {
        return e.time;
      }
    }
    return null;
  }

  /// Number of lines unlocked by [time], including lines owned at start.
  int linesUnlockedBy(double time, int startingLines) =>
      startingLines +
      events
          .where((e) => e.kind == SimEventKind.lineUnlocked && e.time <= time)
          .length;

  /// Longest stretch inside [from, to) with nothing useful to buy.
  double longestIdle(double from, double to) {
    var longest = 0.0;
    for (final (start, end) in idleStretches) {
      final a = start < from ? from : start;
      final b = end > to ? to : end;
      if (b - a > longest) longest = b - a;
    }
    return longest;
  }

  /// Longest stretch without any purchase inside [from, to).
  double longestGap(double from, double to) {
    var last = from;
    var longest = 0.0;
    for (final t in purchaseTimes) {
      if (t < from) {
        last = t > last ? t : last;
        continue;
      }
      if (t >= to) break;
      if (t - last > longest) longest = t - last;
      last = t;
    }
    if (to - last > longest) longest = to - last;
    return longest;
  }
}

class _Candidate {
  const _Candidate(this.label, this.kind, this.cost, this.result);

  final String label;
  final SimEventKind kind;
  final BigNumber cost;

  /// State after the purchase, computed with exactly enough cash.
  final GameState result;
}

/// Plays the game with a greedy "best payback" strategy and records when
/// each milestone of progress happens.
///
/// Each decision, the bot scores every possible purchase by
/// `time to afford + cost / income gained` and buys the best one when it can
/// afford it. Manual lines are tapped one at a time, so the bot also feels
/// the value of managers.
class Simulator {
  const Simulator(this.engine, {this.settings = const SimSettings()});

  final EconomyEngine engine;
  final SimSettings settings;

  SimResult run({required double seconds, GameState? start}) {
    var s = start ?? GameState.initial(engine.config);
    final events = <SimEvent>[];
    final idle = <(double, double)>[];
    double? idleSince;
    final snapshots = <SimSnapshot>[];
    var t = 0.0;
    var nextTap = 0.0;
    var nextDecision = 0.0;
    var nextSnapshot = 0.0;

    while (t < seconds) {
      if (t >= nextSnapshot) {
        snapshots.add(_snapshot(t, s));
        nextSnapshot += settings.snapshotInterval;
      }
      if (t >= nextTap) {
        s = _tapBest(s);
        nextTap += settings.tapInterval;
      }
      if (t >= nextDecision) {
        // Buy as long as the best option is affordable.
        while (true) {
          final best = _bestCandidate(s);
          if (best == null || best.cost > s.cash) break;
          s = best.result.copyWith(cash: s.cash - best.cost);
          events.add(SimEvent(t, best.kind, best.label, best.cost));
        }
        final canBuy = _anyAffordable(s);
        if (!canBuy && idleSince == null) idleSince = t;
        if (canBuy && idleSince != null) {
          idle.add((idleSince, t));
          idleSince = null;
        }
        nextDecision += settings.decisionInterval;
      }
      s = engine.tick(s, settings.step);
      t += settings.step;
    }
    snapshots.add(_snapshot(t, s));
    if (idleSince != null) idle.add((idleSince, t));
    return SimResult(
      events: events,
      idleStretches: idle,
      snapshots: snapshots,
      finalState: s,
      duration: t,
    );
  }

  SimSnapshot _snapshot(double t, GameState s) => SimSnapshot(
    time: t,
    state: s,
    estimatedRate: estimateRate(s),
    efficiency: engine.efficiency(s),
    shares: engine.sharesPreview(s),
  );

  /// Taps the most valuable idle manual line.
  GameState _tapBest(GameState s) {
    int? best;
    var bestIncome = BigNumber.zero;
    for (var i = 0; i < s.lines.length; i++) {
      final l = s.lines[i];
      if (!l.isUnlocked || l.running || engine.hasManager(s, i)) continue;
      final income = engine.incomePerJob(s, i);
      if (best == null || income > bestIncome) {
        best = i;
        bestIncome = income;
      }
    }
    return best == null ? s : engine.tap(s, best);
  }

  /// Expected income per second, discounting manual lines by the reaction
  /// time between a job finishing and the next tap.
  BigNumber estimateRate(GameState s) {
    var total = BigNumber.zero;
    for (var i = 0; i < s.lines.length; i++) {
      if (!s.lines[i].isUnlocked) continue;
      var uptime = 1.0;
      if (!engine.hasManager(s, i)) {
        final cycle = engine.effectiveCycleSeconds(s, i);
        uptime = cycle / (cycle + settings.tapInterval);
      }
      total += engine.lineRate(s, i).scale(uptime);
    }
    return total;
  }

  /// Whether some affordable purchase raises income noticeably. Buying a
  /// level that adds 0.1% income does not count as something to do.
  bool _anyAffordable(GameState s) {
    final rate = estimateRate(s);
    final noticeable = rate.scale(1 + _noticeableGain);
    for (final c in _candidates(s)) {
      if (c.cost <= s.cash && estimateRate(c.result) >= noticeable) return true;
    }
    return false;
  }

  static const _noticeableGain = 0.01;

  _Candidate? _bestCandidate(GameState s) {
    final rate = estimateRate(s);
    _Candidate? best;
    var bestScore = double.infinity;
    for (final c in _candidates(s)) {
      final gain = estimateRate(c.result) - rate;
      if (gain <= BigNumber.zero) continue;
      final missing = c.cost - s.cash;
      final wait = missing.isNegative || rate.isZero
          ? 0.0
          : (missing / rate).toDouble();
      final score = wait + (c.cost / gain).toDouble();
      if (score < bestScore) {
        bestScore = score;
        best = c;
      }
    }
    return best;
  }

  /// Adds infrastructure levels to [s] until it runs at full speed again.
  /// Returns the new state and total cost, or null if nothing was needed.
  (GameState, BigNumber)? _withInfra(GameState s, BigNumber cost) {
    var state = s;
    var total = cost;
    var added = 0;
    while (engine.efficiency(state) < 1 && added < _maxInfraBundle) {
      final kind =
          engine.load(state, InfraKind.power) >=
              engine.load(state, InfraKind.cooling)
          ? InfraKind.power
          : InfraKind.cooling;
      final price = engine.infraCost(state, kind);
      state = engine.buyInfra(state.copyWith(cash: price), kind)!;
      total += price;
      added++;
    }
    return added == 0 ? null : (state, total);
  }

  static const _maxInfraBundle = 10;

  Iterable<_Candidate> _candidates(GameState s) sync* {
    final config = engine.config;
    for (var i = 0; i < s.lines.length; i++) {
      if (!engine.isAvailable(s, i)) continue;
      final level = s.lines[i].level;
      final id = config.lines[i].id;
      final kind = level == 0
          ? SimEventKind.lineUnlocked
          : SimEventKind.purchase;
      final counts = {1};
      final milestone = engine.nextMilestone(level);
      if (level > 0 && milestone != null && milestone.level - level <= 25) {
        counts.add(milestone.level - level);
      }
      for (final count in counts) {
        final cost = engine.levelCost(s, i, count);
        final result = engine.buyLevels(s.copyWith(cash: cost), i, count);
        if (result == null) continue;
        final label = level == 0 ? id : '$id +$count';
        yield _Candidate(label, kind, cost, result);
        // A real player buys the power and cooling the new racks need in the
        // same breath; evaluate that bundle too.
        final bundled = _withInfra(result, cost);
        if (bundled != null) {
          yield _Candidate(label, kind, bundled.$2, bundled.$1);
        }
      }
    }
    for (final m in config.managers) {
      final result = engine.buyManager(s.copyWith(cash: m.cost), m.id);
      if (result != null) {
        yield _Candidate(m.id, SimEventKind.manager, m.cost, result);
      }
    }
    for (final u in config.upgrades) {
      final result = engine.buyUpgrade(s.copyWith(cash: u.cost), u.id);
      if (result != null) {
        yield _Candidate(u.id, SimEventKind.upgrade, u.cost, result);
      }
    }
    for (final kind in InfraKind.values) {
      final cost = engine.infraCost(s, kind);
      final result = engine.buyInfra(s.copyWith(cash: cost), kind);
      if (result != null) {
        yield _Candidate(kind.name, SimEventKind.infra, cost, result);
      }
    }
  }
}
