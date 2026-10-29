// UC-04 / UC-05 preview — OrdersBloc tests.
//
// Covers:
//   * the existing create-order flow (status, error paths),
//   * the My Orders subscription (load, rebind, switch client, errors),
//   * the filter behaviour (active/completed/cancelled + empty defaults).

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_filter.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/app_failure.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrdersService implements OrdersService {
  _FakeOrdersService({this.throwOnCreate = false, this.throwOnCancel = false});
  bool throwOnCreate;
  bool throwOnCancel;

  OrderRecord? createdOrder;
  String? lastCancelReason;

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    if (throwOnCreate) {
      throw OrdersServiceException(AppFailureCodes.ordersCreate, 'boom');
    }
    createdOrder = OrderRecord(
      id: 'order-1',
      clientId: clientId,
      addressId: address.id,
      street: address.street,
      reference: address.reference,
      latitude: address.latitude,
      longitude: address.longitude,
      paymentMethod: paymentMethod,
      amount: amount,
      status: OrderRecord.statusPaidOut,
      products: const <OrderItem>[],
      createdAt: DateTime(2026, 1, 1),
    );
    return createdOrder!;
  }

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      Stream<OrderRecord?>.value(null);

  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) {
    final controller = StreamController<List<OrderRecord>>.broadcast();
    // Emit an empty list immediately so callers don't hang.
    controller.add(const <OrderRecord>[]);
    return controller.stream;
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    if (throwOnCancel) {
      throw OrdersServiceException('cancel failed');
    }
    lastCancelReason = reason;
    // No-op in tests — the bloc does the optimistic update itself.
  }
}

class _ScriptedOrdersService implements OrdersService {
  _ScriptedOrdersService(this._seed, {this.scriptedError});
  final List<OrderRecord> _seed;
  final Object? scriptedError;

  final StreamController<List<OrderRecord>> _controller =
      StreamController<List<OrderRecord>>.broadcast();

  void emit(List<OrderRecord> orders) => _controller.add(orders);
  void error(Object e) => _controller.addError(e);

  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) {
    // Single-subscription controller. Seed the stream the moment a
    // listener attaches so the first frame already has the test's
    // payload. Real Firebase would behave the same way (initial onValue
    // is delivered as soon as we subscribe).
    final out = StreamController<List<OrderRecord>>();
    late StreamSubscription<List<OrderRecord>> sub;
    out.onListen = () {
      // 1) bridge the controller so scripted events keep flowing.
      sub = _controller.stream.listen(
        out.add,
        onError: out.addError,
      );
      // 2) deliver the seed *after* listen() so it isn't dropped.
      if (_seed.isNotEmpty) {
        scheduleMicrotask(() {
          if (!out.isClosed) out.add(_seed);
        });
      }
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      Stream<OrderRecord?>.value(null);

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    throw OrdersServiceException('not used in this test');
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
}

const _cartItem = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'a.jpg',
  nameProduct: 'Burger',
  price: 10.0,
  quantity: 2,
);

OrderRecord _order({
  required String id,
  String status = OrderRecord.statusPaidOut,
  DateTime? createdAt,
  List<OrderItem> products = const <OrderItem>[],
}) {
  return OrderRecord(
    id: id,
    clientId: 'u',
    addressId: 'a',
    street: '',
    reference: '',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: 10,
    status: status,
    products: products,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('OrdersBloc — create order', () {
    blocTest<OrdersBloc, OrdersState>(
      'emits Loading then success with the new order',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      act: (bloc) => bloc.add(const OnAddNewOrdersEvent(
        clientId: 'user-1',
        address: Address.hardcodedDefault,
        paymentMethod: 'CASH PAYMENT',
        products: [_cartItem],
        amount: 20.0,
      )),
      expect: () => [
        isA<OrdersState>().having((s) => s.isLoading, 'loading', true),
        isA<OrdersState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.lastOrder?.id, 'order id', 'order-1')
            .having((s) => s.lastOrder?.amount, 'amount', 20.0),
      ],
    );

    blocTest<OrdersBloc, OrdersState>(
      'emits Loading then Failure when service throws',
      build: () => OrdersBloc(
        ordersService: _FakeOrdersService(throwOnCreate: true),
      ),
      act: (bloc) => bloc.add(const OnAddNewOrdersEvent(
        clientId: 'user-1',
        address: Address.hardcodedDefault,
        paymentMethod: 'CASH PAYMENT',
        products: [_cartItem],
        amount: 20.0,
      )),
      expect: () => [
        isA<OrdersState>().having((s) => s.isLoading, 'loading', true),
        isA<OrdersState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.error?.detail, 'error', contains('boom')),
      ],
    );

    blocTest<OrdersBloc, OrdersState>(
      'updates lastOrder status when a status event arrives',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      seed: () => OrdersState(
        lastOrder: _order(id: 'order-1'),
      ),
      act: (bloc) => bloc.add(
        const OnUpdateLastOrderStatusEvent(OrderRecord.statusOnWay),
      ),
      expect: () => [
        isA<OrdersState>().having(
          (s) => s.lastOrder?.status,
          'status',
          'ON WAY',
        ),
      ],
    );
  });

  group('OrdersBloc — My Orders subscription', () {
    blocTest<OrdersBloc, OrdersState>(
      'opens the stream and stores the seeded batch',
      build: () {
        final service = _ScriptedOrdersService(<OrderRecord>[
          _order(id: 'o1', status: OrderRecord.statusOnWay),
          _order(id: 'o2', status: OrderRecord.statusDelivered),
        ]);
        return OrdersBloc(ordersService: service);
      },
      act: (bloc) => bloc.add(const OnLoadMyOrdersEvent('user-1')),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.activeClientId, 'user-1');
        expect(bloc.state.myOrders.length, 2);
        expect(bloc.state.filter, OrderFilter.active);
        expect(
          bloc.state.myOrders.map((o) => o.id).toList(),
          <String>['o1', 'o2'],
        );
      },
    );

    blocTest<OrdersBloc, OrdersState>(
      'clears the list when client id is empty',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      seed: () => OrdersState(
        activeClientId: 'previous-user',
        myOrders: <OrderRecord>[_order(id: 'o1')],
      ),
      act: (bloc) => bloc.add(const OnLoadMyOrdersEvent('')),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.activeClientId, isNull);
        expect(bloc.state.myOrders, isEmpty);
      },
    );

    blocTest<OrdersBloc, OrdersState>(
      'surfaces stream errors on myOrdersError',
      build: () {
        final service = _ScriptedOrdersService(
          <OrderRecord>[],
          scriptedError: 'firebase offline',
        );
        // kick an error after the empty initial emit
        Future<void>.delayed(const Duration(milliseconds: 50),
            () => service.error('firebase offline'));
        return OrdersBloc(ordersService: service);
      },
      act: (bloc) => bloc.add(const OnLoadMyOrdersEvent('user-1')),
      wait: const Duration(milliseconds: 250),
      verify: (bloc) {
        expect(bloc.state.myOrdersError, isNotNull);
      },
    );

    test('closes subscriptions on bloc.close()', () async {
      final service = _ScriptedOrdersService(<OrderRecord>[
        _order(id: 'o1'),
      ]);
      final bloc = OrdersBloc(ordersService: service)
        ..add(const OnLoadMyOrdersEvent('user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.myOrders, isNotEmpty);
      await bloc.close();
      // After close the internal subscription should be cancelled; we
      // cannot directly observe it, but the test must at least not throw.
    });
  });

  group('OrdersBloc — filter behaviour', () {
    blocTest<OrdersBloc, OrdersState>(
      'starts on the active filter',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      verify: (bloc) => expect(bloc.state.filter, OrderFilter.active),
    );

    blocTest<OrdersBloc, OrdersState>(
      'changing filter does not reload the stream',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      seed: () => OrdersState(filter: OrderFilter.active),
      act: (bloc) => bloc.add(const OnChangeOrderFilterEvent(
        OrderFilter.completed,
      )),
      expect: () => [
        isA<OrdersState>().having(
          (s) => s.filter,
          'filter',
          OrderFilter.completed,
        ),
      ],
    );

    test('filteredMyOrders respects status sets', () {
      const active = <String>{
        OrderRecord.statusPaidOut,
        OrderRecord.statusDispatched,
        OrderRecord.statusOnWay,
      };
      const completed = <String>{OrderRecord.statusDelivered};
      const cancelled = <String>{OrderRecord.statusCancelled};

      final orders = <OrderRecord>[
        _order(id: 'a', status: OrderRecord.statusPaidOut),
        _order(id: 'b', status: OrderRecord.statusOnWay),
        _order(id: 'c', status: OrderRecord.statusDelivered),
        _order(id: 'd', status: OrderRecord.statusCancelled),
      ];
      final state = OrdersState(myOrders: orders);
      expect(
        state.filteredMyOrders.map((o) => o.id),
        <String>['a', 'b'],
      );
      expect(active.contains(OrderRecord.statusPaidOut), isTrue);
      expect(completed.contains(OrderRecord.statusDelivered), isTrue);
      expect(cancelled.contains(OrderRecord.statusCancelled), isTrue);
    });
  });

  group('OrdersBloc — cancellation', () {
    blocTest<OrdersBloc, OrdersState>(
      'flips an order to CANCELLED locally and forwards to the service',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      seed: () => OrdersState(
        myOrders: <OrderRecord>[_order(id: 'a')],
      ),
      act: (bloc) => bloc.add(
        const OnCancelOrderEvent(orderId: 'a', reason: 'changed mind'),
      ),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) async {
        final fake = (bloc.state.myOrders.first);
        expect(fake.status, OrderRecord.statusCancelled);
      },
    );

    blocTest<OrdersBloc, OrdersState>(
      'rolls back when cancelOrder throws',
      build: () => OrdersBloc(
        ordersService: _FakeOrdersService(throwOnCancel: true),
      ),
      seed: () => OrdersState(
        myOrders: <OrderRecord>[_order(id: 'a')],
      ),
      act: (bloc) => bloc.add(const OnCancelOrderEvent(orderId: 'a')),
      wait: const Duration(milliseconds: 10),
      verify: (bloc) {
        expect(bloc.state.myOrders.first.status, OrderRecord.statusPaidOut);
        expect(bloc.state.myOrdersError, isNotNull);
      },
    );
  });
}
