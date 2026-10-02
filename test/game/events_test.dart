import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/game/analytics.dart';
import 'package:gpuempire/game/game_controller.dart';
import 'package:gpuempire/game/game_events.dart';
import 'package:gpuempire/services/analytics_service.dart';
import 'package:gpuempire/services/remote_config.dart';
import 'package:gpuempire/ui/sfx_director.dart';
import 'package:gpuempire/services/sfx_service.dart';

void main() {
  final config = EconomyConfig.fromJson(
    jsonDecode(File('assets/config/economy.json').readAsStringSync())
        as Map<String, Object?>,
  );

  ProviderContainer container(DebugAnalyticsService analytics) {
    final c = ProviderContainer(
      overrides: [
        economyConfigProvider.overrideWithValue(config),
        analyticsServiceProvider.overrideWithValue(analytics),
      ],
    );
    addTearDown(c.dispose);
    c.read(analyticsBridgeProvider);
    return c;
  }

  test('purchases, unlocks and milestones are logged', () {
    final analytics = DebugAnalyticsService();
    final c = container(analytics);
    final game = c.read(gameProvider.notifier);
    game.devAddCash(BigNumber.from(1e9));
    expect(game.buyLevels(1, BuyMode.one), isTrue);
    c.read(buyModeProvider.notifier).select(BuyMode.ten);
    // Level 1 -> 31 crosses the level 25 milestone.
    for (var i = 0; i < 3; i++) {
      expect(game.buyLevels(0, BuyMode.ten), isTrue);
    }
    final names = analytics.events.reversed.map((e) => e.name).toList();
    expect(names, containsAllInOrder(['buy_levels', 'line_unlock']));
    expect(names, contains('milestone'));
    final unlock = analytics.events.firstWhere((e) => e.name == 'line_unlock');
    expect(unlock.params['line'], config.locations[0].lines[1].id);
  });

  test('only the first tap is logged', () {
    final analytics = DebugAnalyticsService();
    final c = container(analytics);
    final game = c.read(gameProvider.notifier);
    game.tap(0);
    game.tick(5);
    game.tap(0);
    expect(analytics.events.where((e) => e.name == 'first_tap'), hasLength(1));
    expect(analytics.events.where((e) => e.name == 'tap'), isEmpty);
  });

  test('debug analytics keeps the newest events', () {
    final analytics = DebugAnalyticsService(capacity: 3);
    for (var i = 0; i < 5; i++) {
      analytics.logEvent('e$i', const {});
    }
    expect(analytics.events.map((e) => e.name), ['e4', 'e3', 'e2']);
  });

  test('remote overrides merge into the economy', () {
    final merged = deepMerge(
      {
        'offline': {'maxSeconds': 7200, 'minReportSeconds': 60},
        'list': [1, 2],
      },
      {
        'offline': {'maxSeconds': 10800},
        'list': [3],
      },
    );
    expect(merged['offline'], {'maxSeconds': 10800, 'minReportSeconds': 60});
    expect(merged['list'], [3]);
  });

  test('purchases, rewards and IPOs have a sound; spending sounds alike', () {
    expect(soundFor(GameEventType.buyUpgrade), Sfx.buy);
    expect(soundFor(GameEventType.ipo), Sfx.fanfare);
    expect(soundFor(GameEventType.questClaim), Sfx.reward);
    expect(soundFor(GameEventType.sessionStart), isNull);
  });
}
