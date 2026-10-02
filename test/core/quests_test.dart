import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/quests.dart';

import 'economy_engine_test.dart' show config, start, withLevels;

void main() {
  final engine = EconomyEngine(config);
  final book = QuestBook(
    engine,
    QuestBook.parse({
      'quests': [
        {
          'id': 'tap',
          'type': 'manualJobs',
          'amount': 2,
          'rewardFraction': 0,
          'minReward': 10,
        },
        {
          'id': 'level',
          'type': 'lineLevel',
          'target': 'a',
          'amount': 5,
          'rewardFraction': 0.5,
          'minReward': 1,
        },
        {
          'id': 'boss',
          'type': 'hireManager',
          'target': 'm_a',
          'amount': 1,
          'rewardFraction': 0,
          'minReward': 1,
        },
        {
          'id': 'power',
          'type': 'infraLevel',
          'target': 'power',
          'amount': 1,
          'rewardFraction': 0,
          'minReward': 1,
        },
        {
          'id': 'all',
          'type': 'allLinesLevel',
          'amount': 3,
          'rewardFraction': 0,
          'minReward': 1,
        },
      ],
    }),
  );

  test('quests come one at a time, in order', () {
    expect(book.current(start())!.id, 'tap');
    expect(book.current(start().copyWith(questIndex: 1))!.id, 'level');
    expect(book.current(start().copyWith(questIndex: 99)), isNull);
  });

  test('manual jobs are counted by the engine', () {
    var s = engine.tap(start(), 0);
    s = engine.tick(s, 1.1);
    expect(s.manualJobs, 1);
    s = engine.tick(engine.tap(s, 0), 1.1);
    expect(book.progress(s, book.current(s)!).isComplete, isTrue);
  });

  test('claim pays the reward and advances', () {
    final ready = start().copyWith(manualJobs: 2);
    final claimed = book.claim(ready)!;
    expect(claimed.cash.toDouble(), 10);
    expect(claimed.totalEarned.toDouble(), 10);
    expect(claimed.questIndex, 1);
  });

  test('cannot claim an unfinished quest', () {
    expect(book.claim(start()), isNull);
  });

  test('reward is a share of earnings with a floor', () {
    final s = withLevels([5, 0])
        .copyWith(questIndex: 1, totalEarned: BigNumber.from(1000));
    final q = book.current(s)!;
    expect(book.reward(s, q).toDouble(), 500);
    expect(book.reward(start(), q).toDouble(), 1);
    expect(book.progress(s, q).fraction, 1);
  });

  test('progress for each quest type', () {
    final s = withLevels([4, 2]).copyWith(managers: {'m_a'}, powerLevel: 1);
    QuestProgress p(String id) =>
        book.progress(s, book.quests.firstWhere((q) => q.id == id));
    expect(p('level').fraction, closeTo(0.8, 1e-9));
    expect(p('boss').isComplete, isTrue);
    expect(p('power').isComplete, isTrue);
    expect(p('all').current, 2);
  });
}
