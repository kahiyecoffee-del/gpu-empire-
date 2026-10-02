import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

import '../core/monetization.dart';
import 'store_service.dart';

/// Google Play Billing / App Store through the official plugin.
class IapStoreService implements StoreService {
  final _iap = InAppPurchase.instance;
  final _purchases = StreamController<String>.broadcast();
  final Map<String, String> _prices = {};
  final Map<String, ProductDetails> _details = {};
  final Map<String, ProductConfig> _configs = {};
  StreamSubscription<List<PurchaseDetails>>? _sub;

  @override
  Future<void> init(List<ProductConfig> products) async {
    for (final p in products) {
      _configs[p.id] = p;
    }
    // Listen first: purchases finished while the app was closed arrive
    // right away.
    _sub ??= _iap.purchaseStream.listen(_onPurchases);
    if (!await _iap.isAvailable()) return;
    final response = await _iap.queryProductDetails(_configs.keys.toSet());
    for (final d in response.productDetails) {
      _details[d.id] = d;
      _prices[d.id] = d.price;
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      if (p.status == PurchaseStatus.purchased ||
          p.status == PurchaseStatus.restored) {
        _purchases.add(p.productID);
      }
      if (p.pendingCompletePurchase) await _iap.completePurchase(p);
    }
  }

  @override
  Stream<String> get purchases => _purchases.stream;

  @override
  Map<String, String> get prices => _prices;

  @override
  Future<bool> buy(ProductConfig product) async {
    final details = _details[product.id];
    if (details == null) return false;
    final param = PurchaseParam(productDetails: details);
    try {
      return product.kind == ProductKind.consumable
          ? await _iap.buyConsumable(purchaseParam: param)
          : await _iap.buyNonConsumable(purchaseParam: param);
    } on Object {
      return false;
    }
  }

  @override
  Future<void> restore() => _iap.restorePurchases();
}
