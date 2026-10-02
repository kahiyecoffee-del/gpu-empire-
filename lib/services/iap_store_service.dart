import 'dart:async';
import 'dart:io' show Platform;

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../core/monetization.dart';
import 'store_service.dart';

/// Google Play Billing / App Store through the official plugin.
class IapStoreService implements StoreService {
  final _iap = InAppPurchase.instance;
  final Map<String, String> _prices = {};
  final Map<String, ProductDetails> _details = {};
  final Map<String, ProductConfig> _configs = {};

  /// Purchases already handled this session (the same purchase can arrive
  /// both as an update and from a restore).
  final Set<String> _handled = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;
  DeliverProduct? _deliver;
  Future<void> _queue = Future.value();

  @override
  Future<void> init(
    List<ProductConfig> products,
    DeliverProduct deliver,
  ) async {
    _deliver = deliver;
    for (final p in products) {
      _configs[p.id] = p;
    }
    // Handle batches one after another so nothing is delivered twice.
    _sub ??= _iap.purchaseStream.listen(
      (list) => _queue = _queue.then((_) => _onPurchases(list)),
    );
    if (!await _iap.isAvailable()) return;
    final response = await _iap.queryProductDetails(_configs.keys.toSet());
    for (final d in response.productDetails) {
      _details[d.id] = d;
      _prices[d.id] = d.price;
    }
    // Android only streams new purchases. Ones that finished while the app
    // was closed (slow payment methods, a crash mid-purchase) come back
    // through a restore; unhandled, Google refunds them after 3 days.
    if (Platform.isAndroid) {
      try {
        await _iap.restorePurchases();
      } on Object {
        // Retried on the next start.
      }
    }
  }

  bool _consumable(String id) => _configs[id]?.kind == ProductKind.consumable;

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      try {
        await _handle(p);
      } on Object {
        // One bad purchase must not stop the rest; the store resends it.
      }
    }
  }

  Future<void> _handle(PurchaseDetails p) async {
    final consumable = _consumable(p.productID);
    final success =
        p.status == PurchaseStatus.purchased ||
        p.status == PurchaseStatus.restored;
    if (success && _configs.containsKey(p.productID)) {
      final key = p.purchaseID ?? p.verificationData.serverVerificationData;
      // iOS restores never include consumables; skip them defensively.
      final skip =
          !_handled.add(key) ||
          (Platform.isIOS && consumable && p.status == PurchaseStatus.restored);
      if (!skip) await _deliver?.call(p.productID);
      if (consumable && Platform.isAndroid) {
        // Consuming also acknowledges, and lets the pack be bought again.
        await _iap
            .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
            .consumePurchase(p);
        return;
      }
    }
    // An Android consumable that failed is left unacknowledged so the next
    // restore delivers and consumes it.
    if (p.pendingCompletePurchase && !(Platform.isAndroid && consumable)) {
      await _iap.completePurchase(p);
    }
  }

  @override
  Map<String, String> get prices => _prices;

  @override
  Future<bool> buy(ProductConfig product) async {
    final details = _details[product.id];
    if (details == null) return false;
    final param = PurchaseParam(productDetails: details);
    try {
      return product.kind == ProductKind.consumable
          // Consumed by hand after delivery (see _handle).
          ? await _iap.buyConsumable(
              purchaseParam: param,
              autoConsume: !Platform.isAndroid,
            )
          : await _iap.buyNonConsumable(purchaseParam: param);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> restore() async {
    try {
      await _iap.restorePurchases();
    } on Object {
      // Billing unavailable; nothing to restore right now.
    }
  }
}
