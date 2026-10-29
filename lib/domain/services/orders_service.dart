import '../models/address.dart';
import '../models/order_record.dart';
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
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
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
}
