import '../models/customer_account.dart';
import '../models/delivery_user.dart';
import '../models/order_record.dart';
import 'app_failure.dart';

/// Errors thrown by the admin orders / delivery services (UC-09).
class AdminOrdersServiceException extends AppFailure {
  AdminOrdersServiceException(super.code, [super.detail]);
}

/// Admin-side orders and delivery-driver operations (UC-09).
///
/// The client-facing [OrdersService] is scoped to a single client; the
/// admin console sees *every* order and can move it through the
/// fulfilment pipeline.
abstract class AdminOrdersService {
  /// Live view of every order in the system, newest first.
  Stream<List<OrderRecord>> watchAllOrders();

  /// Assigns [deliveryUserId] to [orderId] and moves the order to the
  /// "dispatched" stage.
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryUserId,
    required String deliveryUserName,
  });

  /// Moves [orderId] to [status].
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  });
}

/// Admin-side delivery-driver operations (UC-09).
abstract class DeliveryUsersService {
  /// Live view of every account with the delivery role.
  Stream<List<DeliveryUser>> watchDeliveryUsers();

  /// Enables or disables a driver account.
  Future<void> setDeliveryEnabled({
    required String uid,
    required bool enabled,
  });

  /// Creates a brand-new driver account: a Firebase Auth user plus the
  /// `users/{uid}` profile that carries `rolId == 3`.
  ///
  /// Returns the uid of the account that was created.
  Future<String> createDeliveryDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  });

  /// Removes a driver: the profile node is deleted from the database and
  /// the matching Firebase Auth account is removed as well, so the person
  /// can no longer sign in.
  Future<void> deleteDeliveryDriver({
    required String uid,
    required String email,
  });
}

/// Admin-side customer-account operations (UC-07).
///
/// The dashboard counts how many customers registered today, so it needs
/// the account list and the moment each account was created.
abstract class AdminUsersService {
  /// Live view of every account with the customer role.
  Stream<List<CustomerAccount>> watchCustomers();
}
