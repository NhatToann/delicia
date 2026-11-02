// UC-09 — AdminOrdersBloc tests.
//
// Covers:
//   * the realtime order feed,
//   * the status filter,
//   * the delivery assignment (the happy path and the failure),
//   * the status update.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/admin_orders/admin_orders_bloc.dart';
import 'package:delicia/domain/models/admin_order_filter.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

OrderRecord _order({
  required String id,
  String status = OrderRecord.statusPaidOut,
  double amount = 10,
}) {
  return OrderRecord(
    id: id,
    clientId: 'u1',
    addressId: 'a1',
    street: 'Baker Street',
    reference: 'Flat 3',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: status,
    products: const [],
    createdAt: DateTime(2026, 3, 10),
  );
}

void main() {
  group('AdminOrdersBloc — feed & filter', () {
    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'stores the orders that arrive on the stream',
      build: () => AdminOrdersBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[
            _order(id: 'o1'),
            _order(id: 'o2', status: OrderRecord.statusOnWay),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const AdminOrdersLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.orders.length, 2);
        expect(bloc.state.visibleOrders.length, 2);
        expect(bloc.state.filter, AdminOrderFilter.all);
      },
    );

    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'filters the list by status',
      build: () => AdminOrdersBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[
            _order(id: 'o1'),
            _order(id: 'o2', status: OrderRecord.statusOnWay),
            _order(id: 'o3', status: OrderRecord.statusDelivered),
            _order(id: 'o4', status: OrderRecord.statusCancelled),
            _order(id: 'o5', status: OrderRecord.statusPreparing),
          ],
        ),
      ),
      act: (bloc) async {
        bloc.add(const AdminOrdersLoadRequested());
        await Future<void>.delayed(const Duration(milliseconds: 100));
        bloc.add(const AdminOrderFilterChanged(AdminOrderFilter.delivering));
      },
      wait: const Duration(milliseconds: 250),
      verify: (bloc) {
        expect(bloc.state.filter, AdminOrderFilter.delivering);
        expect(bloc.state.visibleOrders.map((o) => o.id), <String>['o2']);
      },
    );

    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'surfaces the stream failure',
      build: () => AdminOrdersBloc(
        ordersService: FakeAdminOrdersService(seedError: 'firebase offline'),
      ),
      act: (bloc) => bloc.add(const AdminOrdersLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });

  group('AdminOrdersBloc — assign delivery', () {
    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'assigns the driver and reports success',
      build: () => AdminOrdersBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[_order(id: 'o1')],
        ),
      ),
      act: (bloc) => bloc.add(
        const AdminOrderAssignDeliveryRequested(
          orderId: 'o1',
          deliveryUserId: 'd1',
          deliveryUserName: 'Nguyễn Tài xế',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.error, isNull);
      },
    );

    test('the service receives the assignment', () async {
      final service = FakeAdminOrdersService(
        orders: <OrderRecord>[_order(id: 'o1')],
      );
      final bloc = AdminOrdersBloc(ordersService: service)
        ..add(const AdminOrdersLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      bloc.add(
        const AdminOrderAssignDeliveryRequested(
          orderId: 'o1',
          deliveryUserId: 'd1',
          deliveryUserName: 'Nguyễn Tài xế',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.assignments.length, 1);
      expect(service.assignments.first['orderId'], 'o1');
      expect(service.assignments.first['deliveryUserId'], 'd1');
      expect(service.assignments.first['deliveryUserName'], 'Nguyễn Tài xế');
      await bloc.close();
    });

    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'surfaces an assignment failure',
      build: () {
        final service = FakeAdminOrdersService(
          orders: <OrderRecord>[_order(id: 'o1')],
        );
        service.throwOnAssign = true;
        return AdminOrdersBloc(ordersService: service);
      },
      act: (bloc) => bloc.add(
        const AdminOrderAssignDeliveryRequested(
          orderId: 'o1',
          deliveryUserId: 'd1',
          deliveryUserName: 'Nguyễn Tài xế',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });

  group('AdminOrdersBloc — status update', () {
    blocTest<AdminOrdersBloc, AdminOrdersState>(
      'moves the order to the preparing stage',
      build: () => AdminOrdersBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[_order(id: 'o1')],
        ),
      ),
      act: (bloc) => bloc.add(
        const AdminOrderStatusUpdateRequested(
          orderId: 'o1',
          status: OrderRecord.statusPreparing,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.error, isNull);
      },
    );
  });
}
