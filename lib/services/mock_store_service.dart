import 'package:flutter/material.dart';

import '../core/monetization.dart';
import 'store_service.dart';

/// A pretend store for the web build and tests. With a [navigatorKey] it
/// asks for confirmation first; nothing is ever charged.
class MockStoreService implements StoreService {
  MockStoreService([this.navigatorKey]);

  final GlobalKey<NavigatorState>? navigatorKey;
  final Map<String, String> _prices = {};
  DeliverProduct? _deliver;

  @override
  Future<void> init(
    List<ProductConfig> products,
    DeliverProduct deliver,
  ) async {
    _deliver = deliver;
    for (final p in products) {
      _prices[p.id] = p.fallbackPrice;
    }
  }

  @override
  Map<String, String> get prices => _prices;

  @override
  Future<bool> buy(ProductConfig product) async {
    final context = navigatorKey?.currentContext;
    if (context != null) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Test purchase'),
          content: Text(
            'This is a test store. Nothing will be charged.\n\n'
            '${product.id} (${product.fallbackPrice})',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Buy'),
            ),
          ],
        ),
      );
      if (!(ok ?? false)) return false;
    }
    await _deliver?.call(product.id);
    return true;
  }

  @override
  Future<void> restore() async {}
}
