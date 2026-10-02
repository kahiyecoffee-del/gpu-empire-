import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/quests.dart';
import 'package:gpuempire/core/simulator.dart';

/// Guards the pacing targets from GAME_BRIEF.md against the real
/// economy.json, so a balancing change that breaks them fails CI.
void main() {
  final config = EconomyConfig.fromJson(
    jsonDecode(File('assets/config/economy.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final engine = EconomyEngine(config);
  final book = QuestBook(
    engine,
    QuestBook.parse(
      jsonDecode(File('assets/config/quests.json').readAsStringSync())
          as Map<String, Object?>,
    ),
  );
  final firstRun = Simulator(engine, questBook: book).run(seconds: 30 * 60);
  final session = Simulator(
    engine,
    questBook: book,
    ipoFactor: 2,
  ).run(seconds: 100 * 60);
  final garage = config.locations.first;
  final startingLines = garage.lines.where((l) => l.startLevel > 0).length;

  test('every location has six lines in unlock order', () {
    expect(config.locations.length, greaterThanOrEqualTo(3));
    for (final loc in config.locations) {
      expect(loc.lines, hasLength(6));
      expect(loc.managers, hasLength(6));
      for (var i = 1; i < loc.lines.length; i++) {
        expect(loc.lines[i].baseCost, greaterThan(loc.lines[i - 1].baseCost));
      }
    }
  });

  test('first upgrade within 60 seconds', () {
    expect(firstRun.firstPurchase, lessThan(60));
  });

  test('three lines open within 5 minutes', () {
    expect(
      firstRun.linesUnlockedBy(300, startingLines),
      greaterThanOrEqualTo(3),
    );
  });

  test('never more than 3 minutes with nothing to do in the first 30 min', () {
    expect(firstRun.longestIdle(0, 30 * 60), lessThanOrEqualTo(180));
  });

  test('second location reached in 30-50 minutes', () {
    final move = session.firstTime(SimEventKind.move);
    expect(move, isNotNull);
    expect(move, inInclusiveRange(30 * 60, 50 * 60));
  });

  test('first IPO in 60-90 minutes', () {
    final ipo = session.firstTime(SimEventKind.ipo);
    expect(ipo, isNotNull);
    expect(ipo, inInclusiveRange(60 * 60, 90 * 60));
  });
}
