import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/economy_config.dart';
import 'core/economy_engine.dart';
import 'core/offline.dart';
import 'core/quests.dart';
import 'game/analytics.dart';
import 'game/game_controller.dart';
import 'game/monetization.dart';
import 'game/session.dart';
import 'services/analytics_service.dart';
import 'services/music_service.dart';
import 'services/platform_services.dart';
import 'services/save_service.dart';
import 'services/remote_config.dart';
import 'services/settings_service.dart';
import 'services/sfx_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Remote overrides are fetched first (with a short timeout) and merged
  // over the bundled economy.
  const RemoteConfigService remote = LocalRemoteConfig();
  await remote.init();
  final config = EconomyConfig.fromJson(
    deepMerge(
      jsonDecode(await rootBundle.loadString('assets/config/economy.json'))
          as Map<String, Object?>,
      remote.economyOverrides,
    ),
  );
  final quests = QuestBook.parse(
    jsonDecode(await rootBundle.loadString('assets/config/quests.json'))
        as Map<String, Object?>,
  );
  final prefs = await SharedPreferences.getInstance();
  final saves = SaveService(PrefsSaveStore(prefs), config);
  final music = LoopingMusicService();
  unawaited(music.prepare());
  // Browsers limit audio contexts: one voice per effect there.
  final sfx = PooledSfxService(voices: kIsWeb ? 1 : 3);
  unawaited(sfx.prepare());
  final analytics = DebugAnalyticsService();
  await analytics.init();

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

  final navigatorKey = GlobalKey<NavigatorState>();
  runApp(
    ProviderScope(
      overrides: [
        economyConfigProvider.overrideWithValue(config),
        questsConfigProvider.overrideWithValue(quests),
        sharedPreferencesProvider.overrideWithValue(prefs),
        musicServiceProvider.overrideWithValue(music),
        sfxServiceProvider.overrideWithValue(sfx),
        analyticsServiceProvider.overrideWithValue(analytics),
        remoteConfigProvider.overrideWithValue(remote),
        saveServiceProvider.overrideWithValue(saves),
        initialGameStateProvider.overrideWithValue(offline?.state),
        initialOfflineReportProvider.overrideWithValue(offline),
        adServiceProvider.overrideWithValue(createAdService(navigatorKey)),
        storeServiceProvider.overrideWithValue(
          createStoreService(navigatorKey),
        ),
      ],
      child: GpuEmpireApp(navigatorKey: navigatorKey),
    ),
  );
}
