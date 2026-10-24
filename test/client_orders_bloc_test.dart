// UC-05 — ClientOrdersBloc unit tests.
//
// Uses an in-memory [_FakeOrdersService] (kept inline rather than shared
// with the existing `test/orders_bloc_test.dart` so the two file's
// responsibilities stay cleanly separated).

import 'dart:async';

import 'package:delicia/domain/bloc/client_orders/client_orders_bloc.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/client_orders_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrdersService implements ClientOrdersService {
  _FakeOrdersService({
    this.throwOnList = false,
    this.throwOnCancel = false,
    this.allowCancel = true,
    List<OrderRecord>? orders,
  }) : orders = orders ?? [];

  bool throwOnList;
  bool throwOnCancel;
  bool allowCancel;
  List<OrderRecord> orders;
  final StreamController<List<OrderRecord>> _listController =
      StreamController<List<OrderRecord>>.broadcast();

  void mutate(List<OrderRecord> next) {
    orders = next;
    _listController.add(next);
  }

  @override
  Future<List<OrderRecord>> listOrdersByClient(String clientId) async {
    if (throwOnList) {
      throw ClientOrdersServiceException('Network down');
    }
    return List<OrderRecord>.from(orders);
  }

  @override
  Stream<List<OrderRecord>> watchClientOrders(String clientId) =>
      _listController.stream;

  @override
  Stream<OrderRecord?> watchOrderUpdates(String orderId) async* {
    for (final o in orders) {
      if (o.id == orderId) {
        yield o;
        return;
      }
    }
    yield null;
  }

  @override
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    if (throwOnCancel) {
      throw ClientOrdersServiceException('cancel failed');
    }
    if (!allowCancel) {
      throw ClientOrdersServiceException(
        'Order can no longer be cancelled (current status: DELIVERED).',
      );
    }
    return OrderRecord(
      id: orderId,
      clientId: 'user-1',
      addressId: 'a',
      street: '',
      reference: '',
      latitude: 0,
      longitude: 0,
      paymentMethod: 'CASH PAYMENT',
      amount: 10,
      status: ClientOrderStatuses.cancelled,
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

OrderRecord _buildOrder({
  required String id,
  String clientId = 'user-1',
  String status = OrderRecord.statusPaidOut,
  double amount = 10,
  DateTime? createdAt,
}) {
  return OrderRecord(
    id: id,
    clientId: clientId,
    addressId: 'a',
    street: '$id street',
    reference: 'District',
    latitude: 10,
    longitude: 106,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: status,
    products: const [],
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('ClientOrdersBloc', () {
    test('initial state is empty / inactive', () {
      final bloc = ClientOrdersBloc(ordersService: _FakeOrdersService());
      expect(bloc.state.orders, isEmpty);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.realtimeActive, isFalse);
      expect(bloc.state.error, isNull);
    });

    test('loads orders for the authenticated user', () async {
      final svc = _FakeOrdersService(
        orders: [
          _buildOrder(id: 'o1'),
          _buildOrder(id: 'o2'),
        ],
      );
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await _settle();
      // Wait for the load async to complete.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.orders.length, 2);
      expect(bloc.state.activeClientId, 'user-1');
    });

    test('surfaces a user-friendly error when list fails', () async {
      final svc = _FakeOrdersService(throwOnList: true);
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.error, contains('Network'));
    });

    test('returns early when called without a uid', () {
      final bloc = ClientOrdersBloc(ordersService: _FakeOrdersService());
      bloc.add(const OnLoadClientOrdersEvent(clientId: ''));
      return Future<void>.delayed(const Duration(milliseconds: 30)).then((_) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.error, contains('Sign in'));
        expect(bloc.state.orders, isEmpty);
      });
    });

    test('realtime subscription toggles the realtimeActive flag', () async {
      final bloc = ClientOrdersBloc(ordersService: _FakeOrdersService());
      bloc.add(const OnSubscribeClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.realtimeActive, isTrue);
      expect(bloc.state.activeClientId, 'user-1');
    });

    test(
      'rejects cancellation of a delivered order without calling service',
      () async {
        final svc = _FakeOrdersService(
          orders: [_buildOrder(id: 'o1', status: OrderRecord.statusDelivered)],
        );
        final bloc = ClientOrdersBloc(ordersService: svc);
        bloc.add(OnCancelOrderEvent(clientId: 'user-1', orderId: 'o1'));
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(bloc.state.error, contains('can no longer be cancelled'));
        // Cancelling flag should never have been set — short circuit
        // happened before any service call.
        expect(bloc.state.cancellingOrderId, isNull);
      },
    );

    test('service-level rejection surfaces as a user-friendly error', () async {
      final svc = _FakeOrdersService(
        allowCancel: false,
        orders: [_buildOrder(id: 'o1')],
      );
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      bloc.add(OnCancelOrderEvent(clientId: 'user-1', orderId: 'o1'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.error, contains('can no longer be cancelled'));
    });

    test('a transport failure while cancelling surfaces as an error', () async {
      final svc = _FakeOrdersService(
        throwOnCancel: true,
        orders: [_buildOrder(id: 'o1')],
      );
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      bloc.add(OnCancelOrderEvent(clientId: 'user-1', orderId: 'o1'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.error, contains('cancel failed'));
      expect(bloc.state.cancellingOrderId, isNull);
    });

    test('clear-error event wipes the previous error', () async {
      final svc = _FakeOrdersService(throwOnList: true);
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.error, isNotNull);
      bloc.add(const OnClearClientOrdersErrorEvent());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.error, isNull);
    });

    test('refresh re-reads the source list', () async {
      var orders = [_buildOrder(id: 'o1')];
      final svc = _FakeOrdersService(orders: orders);
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.orders.length, 1);
      svc.mutate([_buildOrder(id: 'o1'), _buildOrder(id: 'o2')]);
      bloc.add(const OnRefreshClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.orders.length, 2);
    });

    // Regression: a CANCELLED order used to leak into the "Active" tab
    // because the filter relied on the delivery timeline list, which does
    // not contain the CANCELLED terminal state.
    test('cancelled orders are listed in History, never in Active', () async {
      final svc = _FakeOrdersService(
        orders: [
          _buildOrder(id: 'o1'),
          _buildOrder(
            id: 'o2',
            status: OrderRecord.statusDispatched,
          ),
          _buildOrder(
            id: 'o3',
            status: OrderRecord.statusDelivered,
          ),
          _buildOrder(id: 'o4', status: ClientOrderStatuses.cancelled),
        ],
      );
      final bloc = ClientOrdersBloc(ordersService: svc);
      bloc.add(const OnLoadClientOrdersEvent(clientId: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        bloc.state.activeOrders.map((o) => o.id),
        containsAll(<String>['o1', 'o2']),
      );
      expect(
        bloc.state.activeOrders.map((o) => o.id),
        isNot(contains('o3')),
      );
      expect(
        bloc.state.activeOrders.map((o) => o.id),
        isNot(contains('o4')),
      );

      expect(
        bloc.state.historyOrders.map((o) => o.id),
        containsAll(<String>['o3', 'o4']),
      );
      expect(
        bloc.state.historyOrders.map((o) => o.id),
        isNot(contains('o1')),
      );
      expect(
        bloc.state.historyOrders.map((o) => o.id),
        isNot(contains('o2')),
      );
    });
  });
}
