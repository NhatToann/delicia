import '../models/address.dart';
import '../models/order_record.dart';
import '../models/price_breakdown.dart';
import '../models/product_cart.dart';
import 'app_failure.dart';

/// Errors thrown by [OrdersService]. Wrapped so the BLoC layer has a
/// single error type to handle.
///
/// Like every other domain exception this one carries a stable failure
/// *code*; the presentation layer turns it into Vietnamese copy.
class OrdersServiceException extends AppFailure {
  OrdersServiceException(super.code, [super.detail]);
}

/// Abstract orders service interface. Production implementation is
/// [FirebaseOrdersService]. Member A's read-side / cancel operations
/// live alongside the create-order flow defined here.
abstract class OrdersService {
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
    PriceBreakdown? quote,
    double distanceKm = 0.0,
    String? receiverPhone,
    String? receiverName,
  });

  /// Live view of every order belonging to [clientId]. Implementations
  /// may surface an empty list when the user has never placed an order
  /// or when Firebase is not initialised.
  Stream<List<OrderRecord>> watchMyOrders(String clientId);

  Future<OrderRecord?> getOrder(String id);

  Stream<OrderRecord?> watchOrder(String id);

  /// Mark an order as cancelled. The bloc is responsible for permissions
  /// (e.g. only PAID OUT orders can be cancelled); the service just
  /// updates the status in Firebase.
  Future<void> cancelOrder(String orderId, {String? reason});

  // ---- Delivery Flow (UC-10 / UC-11) ----
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId);
  Future<List<OrderRecord>> getAvailableOrders();
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId);
  Stream<List<OrderRecord>> watchAvailableOrders();
  Future<void> acceptOrder(String orderId, String deliveryId, {String? deliveryName});
  Future<void> rejectOrder(String orderId, String deliveryId);

  /// Moves an order to [newStatus] and stamps the lifecycle moment that
  /// status represents.
  ///
  /// The two extra parameters carry the **cash-on-delivery settlement**:
  ///
  /// * [cashCollected] — the courier confirms they took the money at the
  ///   door. When `true` the service writes `cashCollected: true` together
  ///   with `cashCollectedAt` (the moment of collection), in the same
  ///   write as the status change, so a delivered order can never be
  ///   observed without its settlement.
  /// * [collectedAmountVnd] — how much was actually collected, in whole
  ///   VND. It may differ from the quoted total (the customer paid a bit
  ///   less, or handed over a round sum), and the difference is exactly
  ///   what the restaurant needs to reconcile. `null` (or 0) means "the
  ///   quoted amount was collected".
  ///
  /// Both parameters are optional, so every existing caller keeps working
  /// unchanged — a status update without settlement simply writes neither
  /// field.
  Future<void> updateDeliveryStatus(
    String orderId,
    String newStatus, {
    String? deliveryPhoto,
    bool cashCollected = false,
    int? collectedAmountVnd,
  });
}
