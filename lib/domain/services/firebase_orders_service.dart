import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/address.dart';
import '../models/order_item.dart';
import '../models/order_record.dart';
import '../models/product_cart.dart';
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
      throw OrdersServiceException('Cannot create an empty order.');
    }
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      final newRef = ref.push();
      final id = newRef.key;
      if (id == null) {
        throw OrdersServiceException('Failed to generate order id.');
      }
      final items = products
          .map(
            (p) => OrderItem(
              productId: p.uidProduct,
              nameProduct: p.nameProduct,
              picture: p.imageProduct,
              price: p.price,
              quantity: p.quantity,
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
      throw OrdersServiceException('Failed to create order: $e');
    }
  }

  @override
  Future<OrderRecord?> getOrder(String id) async {
    final ref = _ref;
    if (ref == null) {
      throw OrdersServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.child(id).once();
      final value = snap.snapshot.value;
      if (value is! Map) return null;
      return OrderRecord.fromMap(id, Map<dynamic, dynamic>.from(value));
    } catch (e) {
      throw OrdersServiceException('Failed to load order: $e');
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
      throw OrdersServiceException('Failed to watch order: $e');
    });
  }
}