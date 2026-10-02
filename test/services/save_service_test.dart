import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/offline.dart';
import 'package:gpuempire/services/save_migrations.dart';
import 'package:gpuempire/services/save_service.dart';

import '../core/economy_engine_test.dart' show config, withLevels;

void main() {
  final engine = EconomyEngine(config);

  group('SaveService', () {
    test('round trips the state and records the time', () async {
      final store = MemorySaveStore();
      var now = 1000000;
      final saves = SaveService(store, config, clock: () => now);
      final state = withLevels([5, 2], cash: 77).copyWith(managers: {'m_a'});
      await saves.save(state);

      now = 2000000;
      final loaded = await SaveService(store, config, clock: () => now).load();
      expect(loaded, isNotNull);
      expect(loaded!.lastSeenMs, 1000000);
      expect(loaded.state.toJson(config), state.toJson(config));
    });

    test('a missing or corrupt save loads as null', () async {
      final store = MemorySaveStore();
      expect(await SaveService(store, config).load(), isNull);
      store.data = '{not json';
      expect(await SaveService(store, config).load(), isNull);
    });

    test('lastSeen never moves backwards when the clock does', () async {
      final store = MemorySaveStore();
      var now = 5000;
      final saves = SaveService(store, config, clock: () => now);
      await saves.save(withLevels([1, 0]));
      now = 1000; // Clock turned back.
      await saves.save(withLevels([1, 0]));
      expect(saves.lastSeenMs, 5000);
      final stored = jsonDecode(store.data!) as Map<String, Object?>;
      expect(stored['lastSeenMs'], 5000);
      expect(stored['version'], currentSaveVersion);
    });

    test('clear removes the save', () async {
      final store = MemorySaveStore();
      final saves = SaveService(store, config);
      await saves.save(withLevels([1, 0]));
      await saves.clear();
      expect(store.data, isNull);
    });
  });

  group('migrations', () {
    test('current version passes through', () {
      final json = {'version': currentSaveVersion, 'x': 1};
      expect(migrateSave(json), json);
    });

    test('v1 saves migrate to the current format', () {
      final v1 = {
        'version': 1,
        'lastSeenMs': 5,
        'state': {'cash': '1.0e0', 'totalEarned': '5.0e0'},
      };
      final migrated = migrateSave(v1);
      expect(migrated['version'], currentSaveVersion);
      final state = migrated['state']! as Map<String, Object?>;
      expect(state['manualJobs'], 0);
      expect(state['locationIndex'], 0);
      expect(state['locationEarned'], state['totalEarned']);
      final meta = state['meta']! as Map<String, Object?>;
      expect(meta['storyIndex'], 0);
      expect(meta['shares'], '0.0e0');
      expect(state['cash'], '1.0e0');
    });

    test('saves from a newer build are rejected', () {
      expect(
        () => migrateSave({'version': currentSaveVersion + 1}),
        throwsFormatException,
      );
    });
  });

  group('offline earnings', () {
    final managed = withLevels([10, 0]).copyWith(managers: {'m_a'});

    test('pays managed lines for the time away', () {
      final report = catchUp(engine, managed, lastSeenMs: 0, nowMs: 60 * 1000);
      // 10 racks * $2 per 1 s job * 60 s.
      expect(report.earned.toDouble(), 1200);
      expect(report.seconds, 60);
      expect(report.capped, isFalse);
      expect(report.state.playSeconds, managed.playSeconds);
    });

    test('caps the paid time', () {
      final report = catchUp(
        engine,
        managed,
        lastSeenMs: 0,
        nowMs: 10 * 3600 * 1000,
      );
      expect(report.seconds, config.offlineMaxSeconds);
      expect(report.capped, isTrue);
      expect(report.earned.toDouble(), 20 * config.offlineMaxSeconds);
    });

    test('a clock moved backwards pays nothing', () {
      final report = catchUp(engine, managed, lastSeenMs: 5000, nowMs: 1000);
      expect(report.earned, BigNumber.zero);
      expect(report.hasEarnings, isFalse);
    });

    test('manual lines do not earn while away', () {
      final report = catchUp(
        engine,
        withLevels([10, 0]),
        lastSeenMs: 0,
        nowMs: 3600 * 1000,
      );
      expect(report.hasEarnings, isFalse);
    });
  });
}
