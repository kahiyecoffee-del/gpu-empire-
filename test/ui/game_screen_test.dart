import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/app.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/game/game_controller.dart';
import 'package:gpuempire/core/quests.dart';
import 'package:gpuempire/services/save_service.dart';
import 'package:gpuempire/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final config = EconomyConfig.fromJson(
    jsonDecode(File('assets/config/economy.json').readAsStringSync())
        as Map<String, Object?>,
  );

  final quests = QuestBook.parse(
    jsonDecode(File('assets/config/quests.json').readAsStringSync())
        as Map<String, Object?>,
  );

  Future<ProviderContainer> pumpGame(
    WidgetTester tester, {
    bool introSeen = true,
    bool tutorialDone = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      'settings_intro_seen': introSeen,
      'settings_tutorial_done': tutorialDone,
    });
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [
        economyConfigProvider.overrideWithValue(config),
        questsConfigProvider.overrideWithValue(quests),
        sharedPreferencesProvider.overrideWithValue(prefs),
        saveServiceProvider.overrideWithValue(
          SaveService(MemorySaveStore(), config),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GpuEmpireApp(),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('shows the first line and the tap hint', (tester) async {
    await pumpGame(tester);
    expect(find.text('Old GPU'), findsWidgets);
    expect(
      find.textContaining('Tap a rack to run a job', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('tapping a rack runs a job and earns money', (tester) async {
    final container = await pumpGame(tester);
    await tester.tap(find.text('Old GPU').last);
    await tester.pump();
    expect(container.read(gameProvider).lines[0].running, isTrue);
    // Let the frame-driven loop finish the 1 second job.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(container.read(gameProvider).cash.toDouble(), greaterThan(0));
  });

  testWidgets('buy button buys a level when affordable', (tester) async {
    final container = await pumpGame(tester);
    container.read(gameProvider.notifier).devAddCash(BigNumber.from(10));
    await tester.pump();
    await tester.tap(find.text('Buy ×1').first);
    await tester.pump();
    expect(container.read(gameProvider).lines[0].level, 2);
  });

  testWidgets('Max greets new players and gives the first quest', (
    tester,
  ) async {
    await pumpGame(tester, introSeen: false);
    await tester.pump();
    expect(find.text('Meet Max'), findsOneWidget);
    await tester.tap(find.text("Let's build!"));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Max · Your CTO'), findsOneWidget);
  });

  testWidgets('a finished quest can be claimed', (tester) async {
    final container = await pumpGame(tester);
    final game = container.read(gameProvider.notifier);
    game.replace(container.read(gameProvider).copyWith(manualJobs: 5));
    await tester.pump();
    await tester.tap(find.text('Claim'));
    await tester.pump();
    expect(container.read(gameProvider).meta.storyIndex, 1);
  });

  testWidgets('music can be turned off in settings', (tester) async {
    final container = await pumpGame(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Music'), findsOneWidget);
    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    expect(container.read(settingsProvider).musicOn, isFalse);
  });

  testWidgets('an ad adds overclock from the boosts sheet', (tester) async {
    final container = await pumpGame(tester);
    await tester.tap(find.byKey(const ValueKey('boosts_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('ad_overclock')));
    await tester.pump();
    expect(container.read(gameProvider).meta.overclockSeconds, 4 * 3600);
  });

  testWidgets('the free wheel spin pays once', (tester) async {
    final container = await pumpGame(tester);
    await tester.tap(find.byKey(const ValueKey('wheel_button')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('wheel_free')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
    expect(container.read(gameProvider).meta.lastFreeSpinMs, isNot(0));
    expect(find.textContaining('You won'), findsOneWidget);
    expect(find.byKey(const ValueKey('wheel_free')), findsNothing);
  });

  testWidgets('a finished quest can be doubled with an ad', (tester) async {
    final container = await pumpGame(tester);
    final game = container.read(gameProvider.notifier);
    game.replace(container.read(gameProvider).copyWith(manualJobs: 5));
    await tester.pump();
    final before = container.read(gameProvider).cash;
    await tester.tap(find.byKey(const ValueKey('ad_quest')));
    await tester.pump();
    final state = container.read(gameProvider);
    expect(state.meta.storyIndex, 1);
    expect(state.cash > before, isTrue);
  });

  testWidgets('the tutorial walks through tap, buy and closes', (tester) async {
    final container = await pumpGame(tester, tutorialDone: false);
    await tester.pump();
    expect(find.textContaining('Tap the rack'), findsOneWidget);
    final game = container.read(gameProvider.notifier);
    game.tap(0);
    await tester.pump();
    expect(find.textContaining('Keep tapping'), findsOneWidget);
    game.devAddCash(BigNumber.from(10));
    await tester.pump();
    expect(find.textContaining('buy another rack'), findsOneWidget);
    expect(game.buyLevels(0, BuyMode.one), isTrue);
    await tester.pump();
    // Quiet until the intern is affordable.
    expect(find.byKey(const ValueKey('tutorial_bubble')), findsNothing);
    game.devAddCash(BigNumber.from(5000));
    await tester.pump();
    expect(find.textContaining('hire the Intern'), findsOneWidget);
    final intern = container
        .read(engineProvider)
        .managerFor(container.read(gameProvider), 0)!;
    expect(game.buyManager(intern.id), isTrue);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tutorial_ok')));
    await tester.pump();
    expect(container.read(settingsProvider).tutorialDone, isTrue);
    expect(find.byKey(const ValueKey('tutorial_bubble')), findsNothing);
  });

  testWidgets('the tutorial can be skipped', (tester) async {
    final container = await pumpGame(tester, tutorialDone: false);
    await tester.pump();
    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(container.read(settingsProvider).tutorialDone, isTrue);
  });

  testWidgets('a language picked in settings is used right away', (
    tester,
  ) async {
    final container = await pumpGame(tester);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('settings_language')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('language_de')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.byKey(const ValueKey('language_de')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(container.read(settingsProvider).language, 'de');
    expect(find.text('Sprache'), findsOneWidget);
  });
}
