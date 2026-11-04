import 'package:delicia/domain/models/admin_order_filter.dart';
import 'package:delicia/domain/models/delivery_status.dart';
import 'package:delicia/domain/models/driver_info.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the "truth layer" fixes landed on day 1 / day 4 of
/// the strategy council sprint.
///
/// Every case here corresponds to a defect that made the three-role app
/// misbehave in production:
///
///  * `rolId` used three contradictory conventions, so a profile-write
///    failure escalated a normal customer to the admin console.
///  * The admin wrote `deliveryUserId` while the driver flow read
///    `deliveryId`, so an order assigned by the restaurant was invisible to
///    the courier (and stayed in the "available" pool for someone else).
///  * `DeliveryStatus` had no `PREPARING` state, so an order the kitchen
///    had already started on fell back to `pending` on the driver screen.
///  * `PICKED UP` appeared in none of the admin's four tabs.
void main() {
  group('rolId convention (1=Client, 2=Admin, 3=Delivery)', () {
    test('a missing rolId defaults to Client, never to Admin', () {
      final user = User.fromMap(<String, dynamic>{'uid': 'u1'});
      expect(user.rolId, 1);
    });

    test('an unparsable rolId defaults to Client', () {
      final user = User.fromMap(<String, dynamic>{
        'uid': 'u1',
        'rolId': 'not-a-number',
      });
      expect(user.rolId, 1);
    });

    test('an explicit rolId is preserved', () {
      expect(User.fromMap(<String, dynamic>{'rolId': 2}).rolId, 2);
      expect(User.fromMap(<String, dynamic>{'rolId': 3}).rolId, 3);
      expect(User.fromMap(<String, dynamic>{'rolId': '3'}).rolId, 3);
    });
  });

  group('courier identity has a single source of truth', () {
    test('reads the canonical deliveryUserId key', () {
      final order = OrderRecord.fromMap('o1', <String, dynamic>{
        'deliveryUserId': 'driver-1',
        'deliveryUserName': 'Alex',
      });
      expect(order.deliveryUserId, 'driver-1');
      expect(order.deliveryUserName, 'Alex');
    });

    test('falls back to the legacy deliveryId key for historical rows', () {
      final order = OrderRecord.fromMap('o1', <String, dynamic>{
        'deliveryId': 'driver-legacy',
        'deliveryName': 'Legacy Driver',
      });
      expect(order.deliveryUserId, 'driver-legacy');
      expect(order.deliveryUserName, 'Legacy Driver');
    });

    test('the canonical key wins when both keys are present', () {
      final order = OrderRecord.fromMap('o1', <String, dynamic>{
        'deliveryUserId': 'driver-new',
        'deliveryUserName': 'New Driver',
        'deliveryId': 'driver-old',
        'deliveryName': 'Old Driver',
      });
      expect(order.deliveryUserId, 'driver-new');
      expect(order.deliveryUserName, 'New Driver');
    });

    test('an unassigned order has an empty courier uid', () {
      final order = OrderRecord.fromMap('o1', <String, dynamic>{});
      expect(order.deliveryUserId, isEmpty);
    });

    test('toMap writes the canonical key and never the legacy one', () {
      final order = OrderRecord.fromMap('o1', <String, dynamic>{
        'deliveryId': 'driver-legacy',
        'deliveryName': 'Legacy Driver',
      });
      final map = order.toMap();
      expect(map['deliveryUserId'], 'driver-legacy');
      expect(map.containsKey('deliveryId'), isFalse);
      expect(map.containsKey('deliveryName'), isFalse);
    });
  });

  group('DeliveryStatus knows the PREPARING stage', () {
    test('parses PREPARING instead of falling back to pending', () {
      expect(DeliveryStatus.fromString('PREPARING'), DeliveryStatus.preparing);
      expect(DeliveryStatus.fromString('preparing'), DeliveryStatus.preparing);
    });

    test('exposes the canonical database string', () {
      expect(DeliveryStatus.preparing.dbStatus, 'PREPARING');
      expect(DeliveryStatus.preparing.dbStatus, OrderRecord.statusPreparing);
    });

    test('a preparing order cannot be marked delivered', () {
      expect(
        DeliveryStatus.preparing.canTransitionTo(DeliveryStatus.delivered),
        isFalse,
      );
    });

    test('a preparing order can still be assigned to a courier', () {
      expect(
        DeliveryStatus.preparing.canTransitionTo(DeliveryStatus.accepted),
        isTrue,
      );
    });
  });

  group('PICKED UP is visible in the admin tabs', () {
    OrderRecord orderWithStatus(String status) => OrderRecord.fromMap(
          'o1',
          <String, dynamic>{'status': status},
        );

    test('the delivering tab accepts PICKED UP', () {
      expect(
        AdminOrderFilter.delivering.accepts(orderWithStatus('PICKED UP')),
        isTrue,
      );
    });

    test('the delivering tab still accepts DISPATCHED and ON WAY', () {
      expect(
        AdminOrderFilter.delivering.accepts(orderWithStatus('DISPATCHED')),
        isTrue,
      );
      expect(
        AdminOrderFilter.delivering.accepts(orderWithStatus('ON WAY')),
        isTrue,
      );
    });

    test('every known status shows up in at least one admin tab', () {
      const statuses = <String>[
        'PAID OUT',
        'PREPARING',
        'DISPATCHED',
        'PICKED UP',
        'ON WAY',
        'DELIVERED',
        'CANCELLED',
      ];
      for (final status in statuses) {
        final visible = AdminOrderFilter.values
            .any((filter) => filter.accepts(orderWithStatus(status)));
        expect(
          visible,
          isTrue,
          reason: 'status "$status" is invisible in every admin tab',
        );
      }
    });
  });

  group('OrderStage maps every driver milestone', () {
    test('PICKED UP maps onto the on-the-way stage, not onto preparing', () {
      expect(OrderStage.fromStatus('PICKED UP'), OrderStage.onTheWay);
      expect(OrderStage.fromStatus('PICKED_UP'), OrderStage.onTheWay);
    });

    test('the happy path still maps correctly', () {
      expect(OrderStage.fromStatus('PAID OUT'), OrderStage.placed);
      expect(OrderStage.fromStatus('PREPARING'), OrderStage.preparing);
      expect(OrderStage.fromStatus('DISPATCHED'), OrderStage.dispatched);
      expect(OrderStage.fromStatus('ON WAY'), OrderStage.onTheWay);
      expect(OrderStage.fromStatus('DELIVERED'), OrderStage.delivered);
    });
  });
}
