import '../core/monetization.dart';

/// Grants a bought product and resolves once it is safely saved.
typedef DeliverProduct = Future<void> Function(String productId);

/// In-app purchases. The game only talks to this interface.
///
/// Every successful purchase goes through [DeliverProduct] first; only
/// after it resolves is the purchase finished with the store, so a crash in
/// between makes the store resend it instead of losing it.
abstract class StoreService {
  Future<void> init(List<ProductConfig> products, DeliverProduct deliver);

  /// Store price label per product id, when the store has answered.
  Map<String, String> get prices;

  /// Starts a purchase. False if it could not be started.
  Future<bool> buy(ProductConfig product);

  /// Asks the store to resend owned products (required on iOS).
  Future<void> restore();
}
