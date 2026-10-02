import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/economy_config.dart';
import 'core/economy_engine.dart';
import 'core/offline.dart';
import 'core/quests.dart';
import 'game/game_controller.dart';
import 'game/session.dart';
import 'services/music_service.dart';
import 'services/save_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final config = EconomyConfig.fromJson(
    jsonDecode(await rootBundle.loadString('assets/config/economy.json'))
        as Map<String, Object?>,
  );
  final quests = QuestBook.parse(
    jsonDecode(await rootBundle.loadString('assets/config/quests.json'))
        as Map<String, Object?>,
  );
  final prefs = await SharedPreferences.getInstance();
  final saves = SaveService(PrefsSaveStore(prefs), config);
  final music = LoopingMusicService();
  unawaited(music.prepare());

  // Restore the save and pay for the time the game was closed.
  final snapshot = await saves.load();
  OfflineReport? offline;
  if (snapshot != null) {
    offline = catchUp(
      EconomyEngine(config),
      snapshot.state,
      lastSeenMs: snapshot.lastSeenMs,
      nowMs: saves.now(),
    );
  }

  runApp(
    ProviderScope(
      overrides: [
        economyConfigProvider.overrideWithValue(config),
        questsConfigProvider.overrideWithValue(quests),
        sharedPreferencesProvider.overrideWithValue(prefs),
        musicServiceProvider.overrideWithValue(music),
        saveServiceProvider.overrideWithValue(saves),
        initialGameStateProvider.overrideWithValue(offline?.state),
        initialOfflineReportProvider.overrideWithValue(offline),
      ],
      child: const GpuEmpireApp(),
    ),
  );
}
