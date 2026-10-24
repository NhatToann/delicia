import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/order_record.dart';

/// Errors thrown by [ClientOrdersService] (UC-05).
class ClientOrdersServiceException implements Exception {
  final String message;
  ClientOrdersServiceException(this.message);
  @override
  String toString() => message;
}

/// Read-side contract for the client's order history (UC-05).
///
/// This is intentionally a **separate interface** from
/// `lib/domain/services/orders_service.dart` (UC-04, Leader).  The
/// Leader's interface only exposes the write side (`addNewOrder`,
/// `getOrder`, `watchOrder`).  Extending it would force every other team
/// member's fake implementation to add the new members — a guaranteed
/// merge conflict and a broken build on their branch.  Keeping the two
/// contracts apart means UC-05 can ship without touching anyone's file.
///
/// The two implementations read the same database node
/// (`{dbRoot}/orders`), so the data is shared — only the *contract* is
/// separate.
abstract class ClientOrdersService {
  /// Loads every order belonging to [clientId], newest first.
  ///
  /// Implementations must tolerate malformed rows — a single bad record
  /// must not poison the whole list.  Throws
  /// [ClientOrdersServiceException] on transport errors only.
  Future<List<OrderRecord>> listOrdersByClient(String clientId);

  /// Streams the client's order list so status changes coming from the
  /// admin / delivery side flow into the UI without a manual refresh.
  ///
  /// If the transport doesn't support live updates the stream may emit a
  /// single snapshot and close.
  Stream<List<OrderRecord>> watchClientOrders(String clientId);

  /// Streams a single order — used by the order-detail screen.
  Stream<OrderRecord?> watchOrderUpdates(String orderId);

  /// Persists a cancellation against [orderId].
  ///
  /// Implementations must throw [ClientOrdersServiceException] when the
  /// cancellation isn't allowed (invalid state, missing order).  Returns
  /// the updated record on success.
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  });
}

/// Firebase Realtime Database backed [ClientOrdersService].
///
/// Reads from the same node the Leader's write-side service writes to:
///   `{Environment.dbRoot}/orders/{orderId}`
///
/// Note on querying: the Realtime Database requires a declared index for
/// `orderByChild('clientId').equalTo(...)` queries.  Since those indexes
/// are configured in the Firebase Console (outside the repo) and may not
/// exist yet, we read the collection and filter client-side.  This keeps
/// the feature working regardless of the console configuration.
class FirebaseClientOrdersService implements ClientOrdersService {
  FirebaseClientOrdersService({FirebaseDatabase? database})
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

  DatabaseReference? get _ref => _database?.ref('${Environment.dbRoot}/orders');

  @override
  Future<List<OrderRecord>> listOrdersByClient(String clientId) async {
    if (clientId.isEmpty) return const [];
    final ref = _ref;
    if (ref == null) {
      throw ClientOrdersServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      final snap = await ref.once();
      final list = _parseOrders(snap.snapshot.value, ref.key ?? 'orders');
      return _sortForClient(list, clientId);
    } on ClientOrdersServiceException {
      rethrow;
    } catch (e) {
      throw ClientOrdersServiceException('Failed to load orders: $e');
    }
  }

  @override
  Stream<List<OrderRecord>> watchClientOrders(String clientId) {
    if (clientId.isEmpty) {
      return Stream<List<OrderRecord>>.value(const []);
    }
    final ref = _ref;
    if (ref == null) {
      return Stream<List<OrderRecord>>.value(const []);
    }
    final controller = StreamController<List<OrderRecord>>.broadcast();
    StreamSubscription<DatabaseEvent>? sub;
    try {
      sub = ref.onValue.listen(
        (event) {
          if (controller.isClosed) return;
          final list = _parseOrders(event.snapshot.value, ref.key ?? 'orders');
          controller.add(_sortForClient(list, clientId));
        },
        onError: controller.addError,
        cancelOnError: false,
      );
    } catch (e) {
      controller.addError(
        ClientOrdersServiceException('Watch orders failed: $e'),
      );
    }
    controller.onCancel = () async {
      await sub?.cancel();
    };
    return controller.stream;
  }

  @override
  Stream<OrderRecord?> watchOrderUpdates(String orderId) {
    if (orderId.isEmpty) {
      return Stream<OrderRecord?>.value(null);
    }
    final ref = _ref;
    if (ref == null) {
      return Stream<OrderRecord?>.value(null);
    }
    final controller = StreamController<OrderRecord?>.broadcast();
    StreamSubscription<DatabaseEvent>? sub;
    try {
      sub = ref.child(orderId).onValue.listen(
        (event) {
          if (controller.isClosed) return;
          final value = event.snapshot.value;
          if (value is! Map) {
            controller.add(null);
            return;
          }
          controller.add(
            OrderRecord.fromMap(orderId, Map<dynamic, dynamic>.from(value)),
          );
        },
        onError: controller.addError,
        cancelOnError: false,
      );
    } catch (e) {
      controller.addError(
        ClientOrdersServiceException('Watch order failed: $e'),
      );
    }
    controller.onCancel = () async {
      await sub?.cancel();
    };
    return controller.stream;
  }

  @override
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    if (orderId.isEmpty) {
      throw ClientOrdersServiceException('Cannot cancel an order without an id.');
    }
    final ref = _ref;
    if (ref == null) {
      throw ClientOrdersServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      final snap = await ref.child(orderId).once();
      final value = snap.snapshot.value;
      if (value is! Map) {
        throw ClientOrdersServiceException(
          'Order not found — it may have been removed already.',
        );
      }
      final current = OrderRecord.fromMap(
        orderId,
        Map<dynamic, dynamic>.from(value),
      );
      if (!ClientOrderStatuses.cancellableStatuses.contains(current.status)) {
        throw ClientOrdersServiceException(
          'Order can no longer be cancelled (current status: '
          '${current.status}).',
        );
      }
      await ref.child(orderId).update({
        'status': ClientOrderStatuses.cancelled,
        'cancellationReason': reason,
        'cancelledAt': DateTime.now().millisecondsSinceEpoch,
      });
      // Rebuilt by hand rather than via `copyWith` so UC-05 doesn't have to
      // modify the Leader's `OrderRecord` model.
      return OrderRecord(
        id: current.id,
        clientId: current.clientId,
        addressId: current.addressId,
        street: current.street,
        reference: current.reference,
        latitude: current.latitude,
        longitude: current.longitude,
        paymentMethod: current.paymentMethod,
        amount: current.amount,
        status: ClientOrderStatuses.cancelled,
        products: current.products,
        createdAt: current.createdAt,
      );
    } on ClientOrdersServiceException {
      rethrow;
    } catch (e) {
      throw ClientOrdersServiceException('Failed to cancel order: $e');
    }
  }

  /// Filters by client and sorts newest-first.
  List<OrderRecord> _sortForClient(
    List<OrderRecord> orders,
    String clientId,
  ) {
    final mine = orders
        .where((o) => o.clientId.isEmpty || o.clientId == clientId)
        .toList();
    mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  /// Tolerant parser — skips rows that can't be mapped.
  List<OrderRecord> _parseOrders(dynamic raw, String fallbackId) {
    final out = <OrderRecord>[];
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      if (value is! Map) return;
      try {
        out.add(
          OrderRecord.fromMap(
            key?.toString() ?? fallbackId,
            Map<dynamic, dynamic>.from(value),
          ),
        );
      } catch (_) {
        // skip malformed rows
      }
    });
    return out;
  }
}

/// Order statuses recognised by the client flow (UC-05).
///
/// The production data uses the human-readable strings (`PAID OUT`,
/// `DISPATCHED`, `ON WAY`, `DELIVERED`) — these mirror the constants on
/// [OrderRecord].  Cancellation adds a separate terminal state.
class ClientOrderStatuses {
  ClientOrderStatuses._();

  static const String paidOut = OrderRecord.statusPaidOut;
  static const String dispatched = OrderRecord.statusDispatched;
  static const String onWay = OrderRecord.statusOnWay;
  static const String delivered = OrderRecord.statusDelivered;
  static const String cancelled = 'CANCELLED';

  /// Statuses the client is allowed to cancel.  Anything past
  /// `PAID OUT` is out of the client's hands.
  static const Set<String> cancellableStatuses = {paidOut};

  /// Ordered list used by the visual timeline.  A status outside this
  /// list still renders, but doesn't advance the timeline.
  static const List<String> timeline = [paidOut, dispatched, onWay, delivered];

  /// Terminal states — an order in one of these is no longer "active".
  static const Set<String> terminalStatuses = {delivered, cancelled};

  static bool isTerminal(String status) => terminalStatuses.contains(status);
}
