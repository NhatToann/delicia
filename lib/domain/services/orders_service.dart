import '../models/address.dart';
import '../models/order_record.dart';
import '../models/product_cart.dart';

/// Errors thrown by [OrdersService]. Wrapped so the BLoC layer has a
/// single error type to handle.
class OrdersServiceException implements Exception {
  final String message;
  OrdersServiceException(this.message);
  @override
  String toString() => message;
}

/// Abstract orders service interface. Production implementation is
/// [FirebaseOrdersService]. Other order operations (read, status updates,
/// list per client) belong to Member A and Member B in their respective
/// use-cases — we only expose what the Leader needs for UC-04.
abstract class OrdersService {
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  });
  Future<OrderRecord?> getOrder(String id);
  Stream<OrderRecord?> watchOrder(String id);
}