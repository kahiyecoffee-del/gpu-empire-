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
  }) async {
    SharedPreferences.setMockInitialValues({'settings_intro_seen': introSeen});
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
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(container.read(settingsProvider).musicOn, isFalse);
  });
}
