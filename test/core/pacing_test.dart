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
  final quests = QuestBook.parse(
    jsonDecode(File('assets/config/quests.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final result = Simulator(
    engine,
    questBook: QuestBook(engine, quests),
  ).run(seconds: 30 * 60);
  final startingLines = config.lines.where((l) => l.startLevel > 0).length;

  test('economy.json has six lines in unlock order', () {
    expect(config.lines, hasLength(6));
    for (var i = 1; i < config.lines.length; i++) {
      expect(
        config.lines[i].baseCost,
        greaterThan(config.lines[i - 1].baseCost),
      );
    }
  });

  test('first upgrade within 60 seconds', () {
    expect(result.firstPurchase, lessThan(60));
  });

  test('three lines open within 5 minutes', () {
    expect(result.linesUnlockedBy(300, startingLines), greaterThanOrEqualTo(3));
  });

  test('never more than 3 minutes with nothing to do in the first 30 min', () {
    expect(result.longestIdle(0, 30 * 60), lessThanOrEqualTo(180));
  });
}
