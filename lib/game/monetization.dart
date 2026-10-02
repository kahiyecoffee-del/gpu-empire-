import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/monetization.dart';
import '../services/ad_service.dart';
import '../services/mock_store_service.dart';
import '../services/save_service.dart';
import '../services/store_service.dart';
import 'game_controller.dart';
import 'game_events.dart';

/// The ad network. Overridden in `main` per platform.
final adServiceProvider = Provider<AdService>(
  (ref) => const InstantAdService(),
);

/// The store. Overridden in `main` per platform.
final storeServiceProvider = Provider<StoreService>(
  (ref) => MockStoreService(),
);

final adsProvider = Provider<AdsController>(AdsController.new);

/// Whether settings must offer "Privacy options" (asked once).
final privacyOptionsRequiredProvider = FutureProvider<bool>(
  (ref) => ref.watch(adServiceProvider).privacyOptionsRequired(),
);

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
    final bus = _ref.read(gameEventsProvider);
    final params = {'placement': placement.name};
    if (adsRemoved) {
      bus.emit(GameEventType.adRewardComplete, {...params, 'free': 1});
      return true;
    }
    if (_showing) return false;
    _showing = true;
    bus.emit(GameEventType.adRewardStart, params);
    try {
      final watched = await _service.showRewarded(placement);
      if (watched) bus.emit(GameEventType.adRewardComplete, params);
      return watched;
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
      // The gap only restarts when an ad was really shown.
      if (await _service.showInterstitial()) {
        _ref.read(gameEventsProvider).emit(GameEventType.adInterstitial);
        _lastFullScreen = _session.elapsed;
      }
    } finally {
      _showing = false;
    }
  }
}

final storeProvider = Provider<StoreController>(StoreController.new);

/// Whether the app is in the background (set by the session). Saves made
/// then keep the last-seen time, so offline earnings are not swallowed.
final appAwayProvider = NotifierProvider<AppAwayController, bool>(
  AppAwayController.new,
);

class AppAwayController extends Notifier<bool> {
  @override
  bool build() => false;

  void set({required bool away}) => state = away;
}

/// Delivers purchases into the game and saves before the store is told
/// the purchase is done, so a paid product is never lost to a crash.
class StoreController {
  StoreController(this._ref);

  final Ref _ref;
  bool _started = false;

  StoreService get _service => _ref.read(storeServiceProvider);

  MonetizationConfig get _config =>
      _ref.read(economyConfigProvider).monetization;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    await _service.init(_config.products, _deliver);
  }

  Future<void> _deliver(String productId) async {
    final product = _config.products
        .where((p) => p.id == productId)
        .firstOrNull;
    if (product == null) return;
    _ref.read(gameProvider.notifier).deliverProduct(product);
    await _ref
        .read(saveServiceProvider)
        .save(_ref.read(gameProvider), touch: !_ref.read(appAwayProvider));
  }

  String price(ProductConfig product) =>
      _service.prices[product.id] ?? product.fallbackPrice;

  Future<bool> buy(ProductConfig product) => _service.buy(product);

  Future<void> restore() => _service.restore();
}
