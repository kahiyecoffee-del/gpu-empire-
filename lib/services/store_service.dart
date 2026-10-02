import '../core/monetization.dart';

/// In-app purchases. The game only talks to this interface; delivered
/// products arrive on [purchases].
abstract class StoreService {
  Future<void> init(List<ProductConfig> products);

  /// Ids of products to deliver: new purchases and restored ones.
  Stream<String> get purchases;

  /// Store price label per product id, when the store has answered.
  Map<String, String> get prices;

  /// Starts a purchase. False if it could not be started.
  Future<bool> buy(ProductConfig product);

  /// Asks the store to resend owned non-consumables (required on iOS).
  Future<void> restore();
}
