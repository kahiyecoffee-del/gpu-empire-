import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/monetization.dart';
import '../services/ad_service.dart';
import '../services/mock_store_service.dart';
import '../services/save_service.dart';
import '../services/store_service.dart';
import 'game_controller.dart';

/// The ad network. Overridden in `main` per platform.
final adServiceProvider = Provider<AdService>(
  (ref) => const InstantAdService(),
);

/// The store. Overridden in `main` per platform.
final storeServiceProvider = Provider<StoreService>(
  (ref) => MockStoreService(),
);

final adsProvider = Provider<AdsController>(AdsController.new);

/// Ad rules on top of [AdService]: "Remove ads" makes rewarded ads free and
/// turns interstitials off, and interstitials follow [InterstitialPolicy].
class AdsController {
  AdsController(this._ref);

  final Ref _ref;
  final Stopwatch _session = Stopwatch()..start();
  Duration? _lastFullScreen;
  bool _showing = false;

  AdService get _service => _ref.read(adServiceProvider);

  bool get adsRemoved => _ref.read(gameProvider).meta.adsRemoved;

  /// Plays a rewarded ad. True if the reward should be granted.
  Future<bool> watch(AdPlacement placement) async {
    if (adsRemoved) return true;
    if (_showing) return false;
    _showing = true;
    try {
      return await _service.showRewarded(placement);
    } finally {
      _showing = false;
      // A rewarded ad counts as a break too: no interstitial right after.
      _lastFullScreen = _session.elapsed;
    }
  }

  /// Called at natural breaks (moving, after an IPO). Shows an
  /// interstitial only if the policy allows it.
  Future<void> naturalBreak() async {
    final policy = InterstitialPolicy(
      _ref.read(economyConfigProvider).monetization,
    );
    final now = _session.elapsed;
    final last = _lastFullScreen;
    final allowed = policy.canShow(
      sessionSeconds: now.inMilliseconds / 1000,
      secondsSinceLast: last == null
          ? null
          : (now - last).inMilliseconds / 1000,
      adsRemoved: adsRemoved,
    );
    if (!allowed || _showing) return;
    _showing = true;
    try {
      await _service.showInterstitial();
    } finally {
      _showing = false;
      _lastFullScreen = _session.elapsed;
    }
  }
}

final storeProvider = Provider<StoreController>((ref) {
  final controller = StoreController(ref);
  ref.onDispose(controller.dispose);
  return controller;
});

/// Delivers purchases from the store into the game and saves at once, so a
/// paid product is never lost to a crash.
class StoreController {
  StoreController(this._ref);

  final Ref _ref;
  StreamSubscription<String>? _sub;

  StoreService get _service => _ref.read(storeServiceProvider);

  MonetizationConfig get _config =>
      _ref.read(economyConfigProvider).monetization;

  Future<void> init() async {
    _sub ??= _service.purchases.listen(_deliver);
    await _service.init(_config.products);
  }

  void _deliver(String productId) {
    final product = _config.products
        .where((p) => p.id == productId)
        .firstOrNull;
    if (product == null) return;
    _ref.read(gameProvider.notifier).deliverProduct(product);
    unawaited(_ref.read(saveServiceProvider).save(_ref.read(gameProvider)));
  }

  String price(ProductConfig product) =>
      _service.prices[product.id] ?? product.fallbackPrice;

  Future<bool> buy(ProductConfig product) => _service.buy(product);

  Future<void> restore() => _service.restore();

  void dispose() => unawaited(_sub?.cancel());
}
