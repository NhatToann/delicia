import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/address.dart';
import '../models/order_item.dart';
import '../models/order_record.dart';
import '../models/product_cart.dart';
import 'app_failure.dart';
import 'orders_service.dart';

/// Firebase Realtime Database backed [OrdersService] for UC-04.
class FirebaseOrdersService implements OrdersService {
  FirebaseOrdersService({FirebaseDatabase? database})
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

  DatabaseReference? get _ref =>
      _database?.ref('${Environment.dbRoot}/orders');

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    if (products.isEmpty) {
      throw OrdersServiceException(AppFailureCodes.ordersEmpty);
    }
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      final newRef = ref.push();
      final id = newRef.key;
      if (id == null) {
        throw OrdersServiceException(AppFailureCodes.ordersIdGenerate);
      }
      final items = products
          .map(
            (p) => OrderItem(
              productId: p.uidProduct,
              nameProduct: p.nameProduct,
              picture: p.imageProduct,
              price: p.price,
              quantity: p.quantity,
              optionLabel: p.optionLabel,
            ),
          )
          .toList();
      final record = OrderRecord(
        id: id,
        clientId: clientId,
        addressId: address.id,
        street: address.street,
        reference: address.reference,
        latitude: address.latitude,
        longitude: address.longitude,
        paymentMethod: paymentMethod,
        amount: amount,
        status: OrderRecord.statusPaidOut,
        products: items,
        createdAt: DateTime.now(),
      );
      await newRef.set(record.toMap());
      return record;
    } catch (e) {
      if (e is OrdersServiceException) rethrow;
      throw OrdersServiceException(AppFailureCodes.ordersCreate, '$e');
    }
  }

  @override
  Future<OrderRecord?> getOrder(String id) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final snap = await ref.child(id).once();
      final value = snap.snapshot.value;
      if (value is! Map) return null;
      return OrderRecord.fromMap(id, Map<dynamic, dynamic>.from(value));
    } catch (e) {
      throw OrdersServiceException(AppFailureCodes.ordersLoadOne, '$e');
    }
  }

  @override
  Stream<OrderRecord?> watchOrder(String id) {
    final ref = _ref;
    if (ref == null) return Stream<OrderRecord?>.value(null);
    return ref
        .child(id)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) return null;
          return OrderRecord.fromMap(id, Map<dynamic, dynamic>.from(value));
        })
        .handleError((Object e) {
      throw OrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }

  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) {
    final ref = _ref;
    if (ref == null) return Stream<List<OrderRecord>>.value(<OrderRecord>[]);
    return ref
        .orderByChild('clientId')
        .equalTo(clientId)
        .onValue
        .map((event) {
          final value = event.snapshot.value;
          if (value is! Map) return const <OrderRecord>[];
          final out = <OrderRecord>[];
          value.forEach((key, entry) {
            if (entry is Map) {
              out.add(OrderRecord.fromMap(
                key?.toString() ?? '',
                Map<dynamic, dynamic>.from(entry),
              ));
            }
          });
          out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return out;
        })
        .handleError((Object e) {
      throw OrdersServiceException(AppFailureCodes.ordersLoad, '$e');
    });
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final updates = <String, Object>{
        'status': OrderRecord.statusCancelled,
        if (reason case final String r) 'cancelReason': r,
      };
      await ref.child(orderId).update(updates);
    } catch (e) {
      if (e is OrdersServiceException) rethrow;
      throw OrdersServiceException(AppFailureCodes.ordersCancel, '$e');
    }
  }

  // ---- Delivery Flow (UC-10 / UC-11) ----

  @override
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.once();
      final value = snap.snapshot.value;
      if (value is! Map) return const [];
      final list = <OrderRecord>[];
      for (final entry in value.entries) {
        if (entry.value is Map) {
          final record = OrderRecord.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
          if (record.deliveryId == deliveryId) {
            list.add(record);
          }
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw OrdersServiceException('Failed to load delivery orders: $e');
    }
  }

  @override
  Future<List<OrderRecord>> getAvailableOrders() async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.once();
      final value = snap.snapshot.value;
      if (value is! Map) return const [];
      final list = <OrderRecord>[];
      for (final entry in value.entries) {
        if (entry.value is Map) {
          final record = OrderRecord.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
          final isUnassigned =
              record.deliveryId == null || record.deliveryId!.trim().isEmpty;
          final isEligible = record.status == OrderRecord.statusPaidOut ||
              record.status.trim().toUpperCase() == 'PENDING';
          if (isUnassigned && isEligible) {
            list.add(record);
          }
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      throw OrdersServiceException('Failed to load available orders: $e');
    }
  }

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) {
    final ref = _ref;
    if (ref == null) return Stream.value(const []);
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <OrderRecord>[];
      final list = <OrderRecord>[];
      for (final entry in value.entries) {
        if (entry.value is Map) {
          final record = OrderRecord.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
          if (record.deliveryId == deliveryId) {
            list.add(record);
          }
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((Object e) {
      throw OrdersServiceException('Failed to watch delivery orders: $e');
    });
  }

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() {
    final ref = _ref;
    if (ref == null) return Stream.value(const []);
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <OrderRecord>[];
      final list = <OrderRecord>[];
      for (final entry in value.entries) {
        if (entry.value is Map) {
          final record = OrderRecord.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(entry.value as Map),
          );
          final isUnassigned =
              record.deliveryId == null || record.deliveryId!.trim().isEmpty;
          final isEligible = record.status == OrderRecord.statusPaidOut ||
              record.status.trim().toUpperCase() == 'PENDING';
          if (isUnassigned && isEligible) {
            list.add(record);
          }
        }
      }
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }).handleError((Object e) {
      throw OrdersServiceException('Failed to watch available orders: $e');
    });
  }

  @override
  Future<void> acceptOrder(
    String orderId,
    String deliveryId, {
    String? deliveryName,
  }) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      final updates = <String, dynamic>{
        'deliveryId': deliveryId,
        'status': OrderRecord.statusDispatched,
      };
      if (deliveryName != null) {
        updates['deliveryName'] = deliveryName;
      }
      await ref.child(orderId).update(updates);
    } catch (e) {
      throw OrdersServiceException('Failed to accept order: $e');
    }
  }

  @override
  Future<void> rejectOrder(String orderId, String deliveryId) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      await ref.child(orderId).update({
        'deliveryId': '',
        'deliveryName': '',
        'status': OrderRecord.statusPaidOut,
      });
    } catch (e) {
      throw OrdersServiceException('Failed to reject order: $e');
    }
  }

  @override
  Future<void> updateDeliveryStatus(
    String orderId,
    String newStatus, {
    String? deliveryPhoto,
  }) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      final updates = <String, dynamic>{
        'status': newStatus,
      };
      if (deliveryPhoto != null) {
        updates['deliveryPhoto'] = deliveryPhoto;
      }
      await ref.child(orderId).update(updates);
    } catch (e) {
      throw OrdersServiceException('Failed to update delivery status: $e');
    }
  }
}
