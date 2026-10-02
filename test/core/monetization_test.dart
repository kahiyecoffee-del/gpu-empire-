import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gpuempire/core/big_number.dart';
import 'package:gpuempire/core/economy_config.dart';
import 'package:gpuempire/core/economy_engine.dart';
import 'package:gpuempire/core/game_state.dart';
import 'package:gpuempire/core/monetization.dart';
import 'package:gpuempire/core/offline.dart';

void main() {
  final config = EconomyConfig.fromJson(
    jsonDecode(File('assets/config/economy.json').readAsStringSync())
        as Map<String, Object?>,
  );
  final engine = EconomyEngine(config);
  final m = config.monetization;

  /// A garage with the first line at level 10 and managed.
  GameState running() {
    final s = GameState.initial(config);
    final loc = engine.location(s);
    return s
        .withLine(0, const LineState(level: 10))
        .copyWith(managers: {loc.managerForLine(loc.lines[0].id)!.id});
  }

  test('config holds the chosen prices and rewards', () {
    expect(m.overclockMultiplier, 2);
    expect(m.overclockSecondsPerAd, 4 * 3600);
    expect(m.overclockMaxSeconds, 12 * 3600);
    expect(m.product('remove_ads').removesAds, isTrue);
    expect(m.product('starter_pack').tokens, 100);
    expect(m.product('starter_pack').incomeMultiplier, 2);
    expect(m.product('tokens_1400').fallbackPrice, r'$9.99');
    expect(m.timeWarps.map((w) => w.tokens), [20, 60]);
    expect(m.wheel.prizes, hasLength(8));
  });

  group('overclock', () {
    test('doubles income and stacks up to the cap', () {
      final s = running();
      final base = engine.passiveIncomePerSecond(s);
      var o = engine.addOverclock(s);
      expect(o.meta.overclockSeconds, 4 * 3600);
      expect(engine.passiveIncomePerSecond(o), base.scale(2));
      o = engine.addOverclock(engine.addOverclock(engine.addOverclock(o)));
      expect(o.meta.overclockSeconds, 12 * 3600);
      expect(engine.canAddOverclock(o), isFalse);
    });

    test('ends mid-tick and only counts its own seconds', () {
      final s = engine.addOverclock(running(), 10);
      final rate = engine.passiveIncomePerSecond(running());
      final after = engine.tick(s, 30);
      expect(after.meta.overclockSeconds, 0);
      // 10 s doubled + 20 s plain = 40 s worth.
      expect((after.cash / rate.scale(40)).toDouble(), closeTo(1, 0.05));
    });

    test('runs down on the wall clock offline, beyond the cap', () {
      final s = engine.addOverclock(running());
      final away = (config.offlineMaxSeconds + 3600) * 1000;
      final report = catchUp(engine, s, lastSeenMs: 0, nowMs: away.toInt());
      expect(
        report.state.meta.overclockSeconds,
        closeTo(4 * 3600 - config.offlineMaxSeconds - 3600, 1e-6),
      );
    });

    test('survives an IPO and a move', () {
      final s = engine
          .addOverclock(running())
          .copyWith(totalEarned: BigNumber.from(1e12));
      expect(engine.ipo(s)!.meta.overclockSeconds, 4 * 3600);
    });
  });

  test('turbo replaces a weaker boost but not a stronger one', () {
    final s = engine.applyTurbo(running());
    expect(s.boost!.multiplier, m.turboMultiplier);
    final strong = running().copyWith(
      boost: const Boost(multiplier: 10, secondsLeft: 600),
    );
    expect(engine.applyTurbo(strong).boost!.multiplier, 10);
  });

  test('time warp pays steady income for tokens', () {
    final s = running().copyWith(meta: const MetaState(tokens: 25));
    final warp = m.timeWarps.first;
    expect(engine.timeWarp(s.copyWith(meta: const MetaState()), warp), isNull);
    final after = engine.timeWarp(s, warp)!;
    expect(after.meta.tokens, 5);
    expect(after.cash, engine.steadyRate(s).scale(3600));
    // Boosts do not inflate a warp.
    final boosted = engine.applyTurbo(s);
    expect(engine.timeWarpValue(boosted, warp), engine.timeWarpValue(s, warp));
  });

  test('"get it now" only for small gaps, and is not counted as earned', () {
    final s = running().copyWith(cash: BigNumber.from(80));
    expect(
      engine.nearMissing(s, BigNumber.from(100))!.toDouble(),
      closeTo(20, 1e-9),
    );
    expect(engine.nearMissing(s, BigNumber.from(200)), isNull);
    expect(engine.nearMissing(s, BigNumber.from(50)), isNull);
    final granted = engine.grantCash(s, BigNumber.from(20));
    expect(granted.cash, BigNumber.from(100));
    expect(granted.totalEarned, s.totalEarned);
  });

  test('event and quest rewards scale with the ad factor', () {
    final s = running();
    final cash = config.events.list.firstWhere((e) => e.kind == EventKind.cash);
    final once = engine.applyEvent(s, cash).cash;
    expect(engine.applyEvent(s, cash, factor: 2).cash, once.scale(2));
    final boost = config.events.list.firstWhere(
      (e) => e.kind == EventKind.boost,
    );
    expect(
      engine.applyEvent(s, boost, factor: 2).boost!.secondsLeft,
      boost.seconds * 2,
    );
  });

  group('wheel', () {
    const hour = 3600 * 1000;
    final now = DateTime(2026, 10, 2, 12).millisecondsSinceEpoch;

    test('one free spin every 4 hours', () {
      final s = running();
      expect(engine.freeSpinReady(s, now), isTrue);
      final spun = engine.spinWheel(s, 0, free: true, nowMs: now, day: 1)!;
      expect(engine.freeSpinReady(spun, now + 3 * hour), isFalse);
      expect(engine.spinWheel(spun, 0, free: true, nowMs: now, day: 1), isNull);
      expect(engine.freeSpinReady(spun, now + 4 * hour), isTrue);
    });

    test('three ad spins a day, reset the next day', () {
      var s = running();
      for (var i = 0; i < 3; i++) {
        s = engine.spinWheel(s, 0, free: false, nowMs: now, day: 20261002)!;
      }
      expect(engine.adSpinsLeft(s, 20261002), 0);
      expect(
        engine.spinWheel(s, 0, free: false, nowMs: now, day: 20261002),
        isNull,
      );
      expect(engine.adSpinsLeft(s, 20261003), 3);
    });

    test('prizes are picked by weight and applied', () {
      final total = m.wheel.prizes.fold(0.0, (sum, p) => sum + p.weight);
      expect(engine.pickPrize(0), 0);
      expect(engine.pickPrize(0.9999), m.wheel.prizes.length - 1);
      expect(engine.pickPrize(m.wheel.prizes[0].weight / total + 1e-9), 1);

      final s = running();
      for (final (i, prize) in m.wheel.prizes.indexed) {
        final after = engine.applyPrize(s, prize);
        switch (prize.kind) {
          case WheelPrizeKind.cash:
            expect(after.cash > s.cash, isTrue, reason: prize.id);
          case WheelPrizeKind.boost:
            expect(after.boost!.multiplier, prize.value, reason: prize.id);
          case WheelPrizeKind.overclock:
            expect(after.meta.overclockSeconds, prize.value);
          case WheelPrizeKind.tokens:
            expect(after.meta.tokens, prize.value.round());
        }
        expect(i, lessThan(m.wheel.prizes.length));
      }
    });
  });

  group('products', () {
    test('token packs add up every time', () {
      var s = running();
      s = engine.deliverProduct(s, m.product('tokens_100'));
      s = engine.deliverProduct(s, m.product('tokens_100'));
      expect(s.meta.tokens, 200);
    });

    test('starter pack doubles income once, even when restored', () {
      final s = running();
      final base = engine.passiveIncomePerSecond(s);
      final pack = m.product('starter_pack');
      var bought = engine.deliverProduct(s, pack);
      expect(bought.meta.tokens, 100);
      expect(engine.passiveIncomePerSecond(bought), base.scale(2));
      bought = engine.deliverProduct(bought, pack);
      expect(bought.meta.tokens, 100);
      expect(engine.ownsProduct(bought, pack), isTrue);
    });

    test('remove ads is remembered and kept through an IPO', () {
      final s = engine
          .deliverProduct(running(), m.product('remove_ads'))
          .copyWith(totalEarned: BigNumber.from(1e12));
      expect(s.meta.adsRemoved, isTrue);
      expect(engine.ipo(s)!.meta.adsRemoved, isTrue);
    });

    test('new fields round trip and old saves load with defaults', () {
      final s = engine.deliverProduct(running(), m.product('starter_pack'));
      final json =
          jsonDecode(jsonEncode(s.toJson(config))) as Map<String, Object?>;
      final back = GameState.fromJson(json, config);
      expect(back.meta.starterPack, isTrue);
      expect(back.meta.tokens, 100);
      final meta = Map<String, Object?>.of(
        json['meta']! as Map<String, Object?>,
      )..removeWhere((k, _) => k == 'tokens' || k == 'starterPack');
      final old = GameState.fromJson({...json, 'meta': meta}, config);
      expect(old.meta.tokens, 0);
      expect(old.meta.starterPack, isFalse);
    });
  });

  group('interstitial policy', () {
    const policy = InterstitialPolicy(MonetizationConfig());

    test('never in the first 10 minutes', () {
      expect(
        policy.canShow(
          sessionSeconds: 599,
          secondsSinceLast: null,
          adsRemoved: false,
        ),
        isFalse,
      );
      expect(
        policy.canShow(
          sessionSeconds: 600,
          secondsSinceLast: null,
          adsRemoved: false,
        ),
        isTrue,
      );
    });

    test('at least 4 minutes apart', () {
      expect(
        policy.canShow(
          sessionSeconds: 2000,
          secondsSinceLast: 239,
          adsRemoved: false,
        ),
        isFalse,
      );
      expect(
        policy.canShow(
          sessionSeconds: 2000,
          secondsSinceLast: 240,
          adsRemoved: false,
        ),
        isTrue,
      );
    });

    test('never with ads removed', () {
      expect(
        policy.canShow(
          sessionSeconds: 9999,
          secondsSinceLast: null,
          adsRemoved: true,
        ),
        isFalse,
      );
    });
  });
}
