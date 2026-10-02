import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/game_state.dart';

/// Small hand-made config so these tests do not move when the real economy
/// is retuned.
final config = EconomyConfig.fromJson({
  'schemaVersion': 1,
  'startingCash': 0,
  'lines': [
    {
      'id': 'a',
      'baseCost': 10,
      'costGrowth': 1.1,
      'cycleSeconds': 1,
      'baseIncome': 2,
      'power': 1,
      'cooling': 1,
      'startLevel': 1,
    },
    {
      'id': 'b',
      'baseCost': 100,
      'costGrowth': 1.2,
      'cycleSeconds': 4,
      'baseIncome': 50,
      'power': 10,
      'cooling': 5,
    },
  ],
  'milestones': [
    {'level': 50, 'multiplier': 3},
    {'level': 25, 'multiplier': 2},
  ],
  'managers': [
    {'id': 'm_a', 'lineId': 'a', 'cost': 50},
  ],
  'upgrades': [
    {'id': 'u_all', 'lineId': 'all', 'multiplier': 2, 'cost': 500},
    {'id': 'u_b', 'lineId': 'b', 'multiplier': 3, 'cost': 200},
  ],
  'infrastructure': {
    'power': {
      'baseCapacity': 20,
      'capacityGrowth': 2,
      'baseCost': 30,
      'costGrowth': 3,
    },
    'cooling': {
      'baseCapacity': 40,
      'capacityGrowth': 2,
      'baseCost': 30,
      'costGrowth': 3,
    },
  },
  'offline': {'maxSeconds': 7200},
  'prestige': {'k': 2, 'divisor': 1000000, 'exponent': 0.5},
});

final engine = EconomyEngine(config);

GameState start({num cash = 0}) =>
    GameState.initial(config).copyWith(cash: BigNumber.from(cash));

GameState withLevels(List<int> levels, {num cash = 0}) {
  var s = start(cash: cash);
  for (var i = 0; i < levels.length; i++) {
    s = s.withLine(i, s.lines[i].copyWith(level: levels[i]));
  }
  return s;
}

void main() {
  group('config', () {
    test('sorts milestones and upgrades', () {
      expect(config.milestones.map((m) => m.level), [25, 50]);
      expect(config.locations.single.upgrades.map((u) => u.id), [
        'u_b',
        'u_all',
      ]);
    });

    test('initial state uses start levels', () {
      final s = start();
      expect(s.lines.map((l) => l.level), [1, 0]);
      expect(s.cash, BigNumber.zero);
    });
  });

  group('costs', () {
    test('single level cost is base * growth^level', () {
      final s = start();
      expect(engine.levelCost(s, 0, 1).toDouble(), closeTo(11, 1e-9));
      expect(engine.levelCost(s, 1, 1).toDouble(), closeTo(100, 1e-9));
    });

    test('bulk cost equals the sum of single costs', () {
      final s = withLevels([7, 0]);
      var sum = 0.0;
      for (var i = 0; i < 10; i++) {
        sum += 10 * _pow(1.1, 7 + i);
      }
      expect(engine.levelCost(s, 0, 10).toDouble(), closeTo(sum, 1e-6));
    });

    test('maxAffordable is the largest count whose cost fits', () {
      final s = withLevels([1, 0], cash: 1000);
      final k = engine.maxAffordable(s, 0);
      expect(engine.levelCost(s, 0, k) <= s.cash, isTrue);
      expect(engine.levelCost(s, 0, k + 1) > s.cash, isTrue);
    });

    test('maxAffordable is zero for unavailable lines and no cash', () {
      final locked = GameState.initial(config).copyWith(
        lines: const [LineState(), LineState()],
        cash: BigNumber.from(1e9),
      );
      expect(engine.maxAffordable(locked, 1), 0);
      expect(engine.maxAffordable(start(), 0), 0);
    });

    test('maxAffordable handles astronomically large cash', () {
      final s = withLevels([1, 0]).copyWith(cash: BigNumber.fromParts(1, 200));
      final k = engine.maxAffordable(s, 0);
      expect(k, greaterThan(4000));
      expect(engine.levelCost(s, 0, k) <= s.cash, isTrue);
    });
  });

  group('income', () {
    test('milestones multiply income', () {
      expect(engine.milestoneMultiplier(24), 1);
      expect(engine.milestoneMultiplier(25), 2);
      expect(engine.milestoneMultiplier(50), 6);
      expect(engine.nextMilestone(30)!.level, 50);
      expect(engine.nextMilestone(50), isNull);
      final s = withLevels([25, 0]);
      expect(engine.incomePerJob(s, 0).toDouble(), 2 * 25 * 2);
    });

    test('upgrades multiply their line or all lines', () {
      final s = withLevels([2, 1]).copyWith(upgrades: {'u_b', 'u_all'});
      expect(engine.incomePerJob(s, 0).toDouble(), 2 * 2 * 2);
      expect(engine.incomePerJob(s, 1).toDouble(), 50 * 3 * 2);
    });

    test('locked lines earn nothing', () {
      expect(engine.incomePerJob(start(), 1), BigNumber.zero);
    });
  });

  group('throttle', () {
    test('full speed while under capacity', () {
      expect(engine.efficiency(withLevels([20, 0])), 1);
    });

    test('slows down by capacity / demand of the scarcer resource', () {
      // Power demand 30 vs capacity 20; cooling 30 vs 40.
      final s = withLevels([30, 0]);
      expect(engine.load(s, InfraKind.power), closeTo(1.5, 1e-12));
      expect(engine.efficiency(s), closeTo(20 / 30, 1e-12));
      expect(engine.effectiveCycleSeconds(s, 0), closeTo(1.5, 1e-12));
    });

    test('buying infrastructure raises capacity', () {
      final s = withLevels([30, 0], cash: 30);
      final upgraded = engine.buyInfra(s, InfraKind.power)!;
      expect(upgraded.powerLevel, 1);
      expect(upgraded.cash, BigNumber.zero);
      expect(engine.capacity(upgraded, InfraKind.power), 40);
      expect(engine.efficiency(upgraded), 1);
      expect(engine.infraCost(upgraded, InfraKind.power).toDouble(), 90);
    });
  });

  group('actions', () {
    test('buying levels spends cash', () {
      final s = engine.buyLevels(start(cash: 100), 0, 1)!;
      expect(s.lines[0].level, 2);
      expect(s.cash.toDouble(), closeTo(89, 1e-9));
    });

    test('cannot buy what you cannot afford or have not reached', () {
      expect(engine.buyLevels(start(cash: 5), 0, 1), isNull);
      final locked = GameState.initial(config).copyWith(
        lines: const [LineState(), LineState()],
        cash: BigNumber.from(1e6),
      );
      expect(engine.buyLevels(locked, 1, 1), isNull);
      expect(engine.buyLevels(start(cash: 1e6), 0, 0), isNull);
    });

    test('managers need cash and an unlocked line, once', () {
      expect(engine.buyManager(start(cash: 10), 'm_a'), isNull);
      final s = engine.buyManager(start(cash: 60), 'm_a')!;
      expect(s.managers, {'m_a'});
      expect(engine.hasManager(s, 0), isTrue);
      expect(
        engine.buyManager(s.copyWith(cash: BigNumber.from(99)), 'm_a'),
        isNull,
      );
    });

    test('upgrades need their line unlocked', () {
      expect(engine.buyUpgrade(start(cash: 1e6), 'u_b'), isNull);
      final s = engine.buyUpgrade(withLevels([1, 1], cash: 1e6), 'u_b')!;
      expect(s.upgrades, {'u_b'});
      expect(engine.buyUpgrade(s, 'u_b'), isNull);
    });
  });

  group('tick', () {
    test('manual line runs one job per tap', () {
      var s = engine.tap(start(), 0);
      expect(s.lines[0].running, isTrue);
      s = engine.tick(s, 0.6);
      expect(s.cash, BigNumber.zero);
      s = engine.tick(s, 0.6);
      expect(s.cash.toDouble(), 2);
      expect(s.lines[0].running, isFalse);
      // Without a new tap nothing happens.
      s = engine.tick(s, 10);
      expect(s.cash.toDouble(), 2);
      expect(s.totalEarned.toDouble(), 2);
    });

    test('tapping a running or locked line does nothing', () {
      final running = engine.tap(start(), 0);
      expect(identical(engine.tap(running, 0), running), isTrue);
      final s = start();
      expect(identical(engine.tap(s, 1), s), isTrue);
    });

    test('managed line completes every job in a long tick', () {
      final s = start().copyWith(managers: {'m_a'});
      final after = engine.tick(s, 3600.5);
      expect(after.cash.toDouble(), 2 * 3600);
      expect(after.lines[0].progress, closeTo(0.5, 1e-6));
      expect(engine.passiveIncomePerSecond(s).toDouble(), 2);
    });

    test('throttle slows production', () {
      final s = withLevels([30, 0]).copyWith(managers: {'m_a'});
      final after = engine.tick(s, 30);
      // 30 racks * $2 * milestone x2 per job, one job per 1.5 s.
      expect(after.cash.toDouble(), closeTo(120 * 20, 1e-6));
    });

    test('play time is counted unless disabled', () {
      final s = start();
      expect(engine.tick(s, 5).playSeconds, 5);
      expect(engine.tick(s, 5, countPlayTime: false).playSeconds, 0);
    });
  });

  group('prestige', () {
    test('shares = floor(k * (earned / divisor) ^ exponent)', () {
      final s = start().copyWith(totalEarned: BigNumber.from(4e6));
      expect(engine.sharesPreview(s).toDouble(), 4);
      expect(engine.sharesPreview(start()), BigNumber.zero);
    });
  });

  group('save format', () {
    test('state round trips through JSON', () {
      final s = withLevels([12, 3], cash: 1234.5).copyWith(
        managers: {'m_a'},
        upgrades: {'u_b'},
        powerLevel: 2,
        coolingLevel: 1,
        playSeconds: 99,
        totalEarned: BigNumber.fromParts(5, 80),
      );
      final restored = GameState.fromJson(s.toJson(config), config);
      expect(restored.toJson(config), s.toJson(config));
    });

    test('lines missing from a save start fresh', () {
      final json = start().toJson(config);
      (json['lines']! as Map<String, Object?>).remove('b');
      final restored = GameState.fromJson(json, config);
      expect(restored.lines[1].level, 0);
    });
  });
}

double _pow(double base, int exponent) {
  var result = 1.0;
  for (var i = 0; i < exponent; i++) {
    result *= base;
  }
  return result;
}
