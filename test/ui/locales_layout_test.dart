import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/app.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/core/quests.dart';
import 'package:gpuempire/game/events.dart';
import 'package:gpuempire/game/game_controller.dart';
import 'package:gpuempire/services/save_service.dart';
import 'package:gpuempire/services/settings_service.dart';
import 'package:gpuempire/ui/languages.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Renders the main screen and every sheet in all languages on a small
/// phone and fails on any layout overflow, so long translations cannot
/// break the UI unnoticed.
void main() {
  final config = EconomyConfig.fromJson(
    jsonDecode(File('assets/config/economy.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final quests = QuestBook.parse(
    jsonDecode(File('assets/config/quests.json').readAsStringSync())
        as Map<String, Object?>,
  );

  setUpAll(() async {
    // The real font, so Latin text has realistic widths.
    final inter = FontLoader('Inter');
    for (final w in ['Regular', 'SemiBold', 'Bold']) {
      final bytes = File('assets/fonts/Inter-$w.ttf').readAsBytesSync();
      inter.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await inter.load();
  });

  Future<ProviderContainer> pump(WidgetTester tester, String tag) async {
    SharedPreferences.setMockInitialValues({
      'settings_intro_seen': true,
      'settings_tutorial_done': true,
      'settings_infra_hint_seen': true,
      'settings_language': tag,
    });
    final prefs = await SharedPreferences.getInstance();
    // A small Android phone (360 x 740 dp).
    tester.view.physicalSize = const Size(1080, 2220);
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
    // A busy mid-game screen: several lines, a manager, a finished quest,
    // overclock, a boost and an event.
    final game = container.read(gameProvider.notifier)
      ..devAddCash(BigNumber.from(1e9));
    for (var i = 0; i < 4; i++) {
      game.buyLevels(i, BuyMode.one);
    }
    game
      ..buyManager(config.locations[0].managers.first.id)
      ..replace(container.read(gameProvider).copyWith(manualJobs: 5))
      ..addOverclock()
      ..turbo();
    container.read(eventProvider.notifier).spawnNow();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const GpuEmpireApp(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return container;
  }

  Future<void> openAndClose(WidgetTester tester, Finder button) async {
    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  for (final (tag, _) in languages) {
    testWidgets('no overflow in $tag', (tester) async {
      await pump(tester, tag);
      await openAndClose(tester, find.byKey(const ValueKey('wheel_button')));
      await openAndClose(tester, find.byIcon(Icons.settings));
      await openAndClose(tester, find.byIcon(Icons.rocket_launch));
      await openAndClose(tester, find.byIcon(Icons.account_balance));
      // Boosts, then the shop tab.
      await tester.tap(find.byKey(const ValueKey('boosts_button')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(Tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      // The skills tab of the investors sheet is checked separately below.
    });
  }

  for (final (tag, _) in languages) {
    testWidgets('no overflow in skills ($tag)', (tester) async {
      await pump(tester, tag);
      await tester.tap(find.byIcon(Icons.account_balance));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byType(Tab).last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
