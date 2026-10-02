import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/game_state.dart';

Map<String, Object?> _location(String id, {num? goal, num income = 1}) => {
  'id': id,
  'goal': ?goal,
  'lines': [
    {
      'id': '${id}_a',
      'baseCost': 10,
      'costGrowth': 1.1,
      'cycleSeconds': 1,
      'baseIncome': income,
      'power': 1,
      'cooling': 1,
      'startLevel': 1,
    },
    {
      'id': '${id}_b',
      'baseCost': 100,
      'costGrowth': 1.2,
      'cycleSeconds': 2,
      'baseIncome': 10 * income,
      'power': 1,
      'cooling': 1,
    },
  ],
  'managers': [
    {
      'id': '${id}_boss',
      'role': 'intern',
      'lineId': '${id}_a',
      'cost': 50,
      'bonus': {'type': 'lineIncome', 'value': 2},
    },
    {
      'id': '${id}_eng',
      'role': 'chief_engineer',
      'lineId': '${id}_b',
      'cost': 60,
      'bonus': {'type': 'infraDiscount', 'value': 0.5},
    },
  ],
  'upgrades': <Object?>[],
  'infrastructure': {
    'power': {
      'baseCapacity': 1000,
      'capacityGrowth': 2,
      'baseCost': 100,
      'costGrowth': 2,
    },
    'cooling': {
      'baseCapacity': 1000,
      'capacityGrowth': 2,
      'baseCost': 100,
      'costGrowth': 2,
    },
  },
};

final config = EconomyConfig.fromJson({
  'schemaVersion': 2,
  'startingCash': 0,
  'milestones': <Object?>[],
  'offline': {'maxSeconds': 7200},
  'prestige': {'k': 1, 'divisor': 100, 'exponent': 0.5, 'bonusPerShare': 0.1},
  'skills': [
    {
      'id': 'money',
      'branch': 'income',
      'cost': 2,
      'effect': 'incomeMultiplier',
      'value': 3,
    },
    {
      'id': 'more_money',
      'branch': 'income',
      'cost': 2,
      'effect': 'incomeMultiplier',
      'value': 2,
      'requires': 'money',
    },
    {
      'id': 'cash',
      'branch': 'automation',
      'cost': 1,
      'effect': 'startCash',
      'value': 500,
    },
    {
      'id': 'hire',
      'branch': 'automation',
      'cost': 1,
      'effect': 'startManagers',
      'value': 1,
    },
    {
      'id': 'sleep',
      'branch': 'automation',
      'cost': 1,
      'effect': 'offlineHours',
      'value': 8,
    },
  ],
  'events': {
    'minInterval': 10,
    'maxInterval': 20,
    'lifetime': 5,
    'list': [
      {'id': 'boost', 'kind': 'boost', 'value': 10, 'seconds': 5},
      {'id': 'cash', 'kind': 'cash', 'value': 60},
    ],
  },
  'locations': [
    _location('garage', goal: 1000),
    _location('warehouse', income: 5),
  ],
});

final engine = EconomyEngine(config);

GameState start() => GameState.initial(config);

void main() {
  group('locations', () {
    test('cannot move before the goal', () {
      expect(engine.canMove(start()), isFalse);
      expect(engine.moveToNextLocation(start()), isNull);
      expect(engine.locationProgress(start()), 0);
    });

    test('moving starts the new location fresh but keeps run progress', () {
      final rich = start()
          .earn(BigNumber.from(1500))
          .copyWith(managers: {'garage_boss'}, powerLevel: 3);
      expect(engine.locationProgress(rich), 1);
      final moved = engine.moveToNextLocation(rich)!;
      expect(moved.locationIndex, 1);
      expect(engine.location(moved).id, 'warehouse');
      expect(moved.cash, BigNumber.zero);
      expect(moved.locationEarned, BigNumber.zero);
      expect(moved.totalEarned.toDouble(), 1500);
      expect(moved.managers, isEmpty);
      expect(moved.powerLevel, 0);
      expect(moved.lines.map((l) => l.level), [1, 0]);
      // The last location has nowhere to go.
      expect(engine.nextLocation(moved), isNull);
      expect(engine.canMove(moved.earn(BigNumber.from(1e9))), isFalse);
    });

    test('later locations earn more for the same racks', () {
      final moved = engine.moveToNextLocation(
        start().earn(BigNumber.from(1000)),
      )!;
      expect(engine.incomePerJob(moved, 0).toDouble(), 5);
      expect(engine.incomePerJob(start(), 0).toDouble(), 1);
    });
  });

  group('managers', () {
    test('line bonus multiplies only their line', () {
      final s = start()
          .withLine(1, const LineState(level: 1))
          .copyWith(managers: {'garage_boss'});
      expect(engine.incomePerJob(s, 0).toDouble(), 2);
      expect(engine.incomePerJob(s, 1).toDouble(), 10);
    });

    test('infrastructure discount lowers power and cooling prices', () {
      final s = start().copyWith(managers: {'garage_eng'});
      expect(engine.infraCost(s, InfraKind.power).toDouble(), 50);
    });

    test("buying another location's manager fails", () {
      final s = start().copyWith(cash: BigNumber.from(1e6));
      expect(engine.buyManager(s, 'warehouse_boss'), isNull);
    });
  });

  group('IPO', () {
    test('needs at least one share', () {
      expect(engine.canIpo(start()), isFalse);
      expect(engine.ipo(start()), isNull);
    });

    test('resets the run and keeps meta progress', () {
      final s = start()
          .earn(BigNumber.from(10000))
          .copyWith(locationIndex: 1, managers: {'x'});
      // sqrt(10000 / 100) = 10 shares.
      expect(engine.sharesPreview(s).toDouble(), 10);
      final after = engine.ipo(s)!;
      expect(after.meta.shares.toDouble(), 10);
      expect(after.meta.ipoCount, 1);
      expect(after.locationIndex, 0);
      expect(after.cash, BigNumber.zero);
      expect(after.totalEarned, BigNumber.zero);
      expect(after.managers, isEmpty);
      expect(after.meta.lifetimeEarned.toDouble(), 10000);
    });

    test('each share adds its bonus to all income', () {
      final s = start().copyWith(meta: MetaState(shares: BigNumber.from(10)));
      // 1 + 10 * 0.1 = x2.
      expect(engine.incomePerJob(s, 0).toDouble(), 2);
    });
  });

  group('skills', () {
    final rich = start().copyWith(meta: MetaState(shares: BigNumber.from(10)));

    test('cost shares and need their prerequisite', () {
      expect(engine.buySkill(rich, 'more_money'), isNull);
      final s = engine.buySkill(rich, 'money')!;
      expect(s.meta.shares.toDouble(), 8);
      expect(engine.buySkill(s, 'money'), isNull);
      final both = engine.buySkill(s, 'more_money')!;
      expect(both.meta.skills, {'money', 'more_money'});
      // x3 * x2 skills, x(1 + 6 * 0.1) shares.
      expect(engine.incomePerJob(both, 0).toDouble(), closeTo(6 * 1.6, 1e-9));
    });

    test('start-of-run skills apply after an IPO', () {
      var s = rich;
      for (final id in ['cash', 'hire']) {
        s = engine.buySkill(s, id)!;
      }
      final run = engine.ipo(s.earn(BigNumber.from(10000)))!;
      expect(run.cash.toDouble(), 500);
      expect(run.managers, {'garage_boss'});
    });

    test('offline cap is raised by skills', () {
      expect(engine.offlineCapSeconds(start()), 7200);
      final s = engine.buySkill(rich, 'sleep')!;
      expect(engine.offlineCapSeconds(s), 8 * 3600);
    });
  });

  group('events and boosts', () {
    test('boost multiplies income and runs out', () {
      final event = config.events.list.first;
      final s = engine.applyEvent(start(), event);
      expect(engine.incomePerJob(s, 0).toDouble(), 10);
      final later = engine.tick(s, 6);
      expect(later.boost, isNull);
      expect(engine.incomePerJob(later, 0).toDouble(), 1);
    });

    test('a long tick only boosts the boosted seconds', () {
      final managed = start().copyWith(managers: {'garage_boss'});
      final boosted = engine.applyEvent(managed, config.events.list.first);
      // 5 s at x10 then 95 s plain; the manager doubles line income.
      final after = engine.tick(boosted, 100);
      expect(after.cash.toDouble(), closeTo(5 * 20 + 95 * 2, 1e-6));
    });

    test('cash event pays seconds of full-speed income', () {
      final s = engine.applyEvent(start(), config.events.list.last);
      expect(s.cash.toDouble(), 60);
      expect(s.locationEarned.toDouble(), 60);
    });
  });
}
