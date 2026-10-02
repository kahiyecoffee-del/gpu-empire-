import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/game_state.dart';
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
    expect(
      book.current(start().copyWith(meta: const MetaState(storyIndex: 1)))!.id,
      'level',
    );
    expect(
      book.current(start().copyWith(meta: const MetaState(storyIndex: 99))),
      isNull,
    );
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
    expect(claimed.meta.storyIndex, 1);
  });

  test('cannot claim an unfinished quest', () {
    expect(book.claim(start()), isNull);
  });

  test('reward is a share of location earnings with a floor', () {
    final s = withLevels([5, 0]).copyWith(
      meta: const MetaState(storyIndex: 1),
      totalEarned: BigNumber.from(5000),
      locationEarned: BigNumber.from(1000),
    );
    final q = book.current(s)!;
    // Based on what this location earned, not the whole run.
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

  test('contracts take over when the story quest is out of reach', () {
    final board = QuestBoard(book, ContractBook(engine));
    // Story quest 1 levels line 'a', available here.
    final s = start().copyWith(meta: const MetaState(storyIndex: 1));
    expect(board.active(s).$2, isFalse);
    // Past the end of the story, contracts appear.
    final done = start().copyWith(meta: const MetaState(storyIndex: 99));
    final (contract, isContract) = board.active(done);
    expect(isContract, isTrue);
    expect(contract.type, QuestType.lineLevel);
    // The contract is frozen when issued: levelling up does not move it.
    final issued = board.ensure(done);
    final goal = board.active(issued).$1.amount;
    final levelled = issued.withLine(0, const LineState(level: 30));
    expect(board.active(levelled).$1.amount, goal);
    // Claiming advances the contract counter and alternates the type.
    final claimed = board.claim(levelled)!;
    expect(claimed.contractIndex, 1);
    expect(board.active(claimed).$1.type, QuestType.locationEarned);
  });
}
