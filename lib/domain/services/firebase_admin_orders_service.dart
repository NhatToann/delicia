import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/customer_account.dart';
import '../models/delivery_user.dart';
import '../models/order_record.dart';
import 'admin_orders_service.dart';
import 'app_failure.dart';

/// Firebase Realtime Database backed [AdminOrdersService] (UC-09).
///
/// Unlike the client-facing orders service, this one watches the whole
/// `delicia/orders` node — the restaurant sees every order, not just one
/// customer's.
class FirebaseAdminOrdersService implements AdminOrdersService {
  FirebaseAdminOrdersService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _ordersRef =>
      _database?.ref('${Environment.dbRoot}/orders');

  @override
  Stream<List<OrderRecord>> watchAllOrders() {
    final ref = _ordersRef;
    if (ref == null) {
      return Stream<List<OrderRecord>>.value(const <OrderRecord>[]);
    }
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <OrderRecord>[];
      final out = <OrderRecord>[];
      value.forEach((key, entry) {
        if (entry is Map) {
          out.add(
            OrderRecord.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(entry),
            ),
          );
        }
      });
      // Newest first — the admin works the queue from the top.
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    }).handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }

  @override
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryUserId,
    required String deliveryUserName,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(orderId).update(<String, Object>{
        'deliveryUserId': deliveryUserId,
        'deliveryUserName': deliveryUserName,
        'status': OrderRecord.statusDispatched,
      });
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersAssignDelivery,
        '$e',
      );
    }
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(orderId).update(<String, Object>{'status': status});
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersUpdateStatus,
        '$e',
      );
    }
  }
}

/// Firebase Realtime Database backed [DeliveryUsersService] (UC-09).
///
/// The delivery drivers live in the shared `users/{uid}` node, told
/// apart by `rolId == 3`. The `enabled` flag is written next to the
/// profile so the admin console can disable a driver without touching
/// Firebase Auth (the account stays, only the dispatch is blocked).
class FirebaseDeliveryUsersService implements DeliveryUsersService {
  FirebaseDeliveryUsersService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _usersRef => _database?.ref('users');

  @override
  Stream<List<DeliveryUser>> watchDeliveryUsers() {
    final ref = _usersRef;
    if (ref == null) {
      return Stream<List<DeliveryUser>>.value(const <DeliveryUser>[]);
    }
    // The number of orders a driver is currently carrying is derived from
    // the orders node — it is not stored on the profile, and it has to
    // stay in sync when a driver is dispatched.
    final ordersRef = _database?.ref('${Environment.dbRoot}/orders');
    if (ordersRef == null) {
      return ref.onValue.map((event) => _parseUsers(event));
    }
    return ref.onValue
        .asyncMap((event) async {
          final orders = await ordersRef.once();
          final counts = _activeOrderCounts(orders);
          return _parseUsers(event, activeOrders: counts);
        })
        .handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }

  /// Counts the in-flight orders per driver.
  static Map<String, int> _activeOrderCounts(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const <String, int>{};
    final counts = <String, int>{};
    value.forEach((_, entry) {
      if (entry is! Map) return;
      final uid = (entry['deliveryUserId'] ?? '').toString();
      if (uid.isEmpty) return;
      final status = (entry['status'] ?? '').toString();
      if (status == OrderRecord.statusDelivered ||
          status == OrderRecord.statusCancelled) {
        return;
      }
      counts[uid] = (counts[uid] ?? 0) + 1;
    });
    return counts;
  }

  /// Turns a `users/{uid}` snapshot into the driver list.
  static List<DeliveryUser> _parseUsers(
    DatabaseEvent event, {
    Map<String, int> activeOrders = const <String, int>{},
  }) {
    final value = event.snapshot.value;
    if (value is! Map) return const <DeliveryUser>[];
    final out = <DeliveryUser>[];
    value.forEach((key, entry) {
      if (entry is! Map) return;
      if (int.tryParse((entry['rolId'] ?? '').toString()) != 3) return;
      final uid = key.toString();
      out.add(
        DeliveryUser.fromMap(
          uid,
          Map<dynamic, dynamic>.from(entry),
        ).copyWith(activeOrders: activeOrders[uid] ?? 0),
      );
    });
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<void> setDeliveryEnabled({
    required String uid,
    required bool enabled,
  }) async {
    final ref = _usersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(uid).update(<String, Object>{'enabled': enabled});
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryToggleEnabled,
        '$e',
      );
    }
  }
}

/// Firebase Realtime Database backed [AdminUsersService] (UC-07).
///
/// The customers live in the shared `users/{uid}` node, told apart by
/// `rolId == 2`.
class FirebaseAdminUsersService implements AdminUsersService {
  FirebaseAdminUsersService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _usersRef => _database?.ref('users');

  @override
  Stream<List<CustomerAccount>> watchCustomers() {
    final ref = _usersRef;
    if (ref == null) {
      return Stream<List<CustomerAccount>>.value(const <CustomerAccount>[]);
    }
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <CustomerAccount>[];
      final out = <CustomerAccount>[];
      value.forEach((key, entry) {
        if (entry is! Map) return;
        if (int.tryParse((entry['rolId'] ?? '').toString()) != 2) return;
        out.add(
          CustomerAccount.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(entry),
          ),
        );
      });
      return out;
    }).handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }
}
