// UC-04 — OrdersBloc tests (create-order only; read/update are owned by
// Member A / Member B in their respective use-cases).

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrdersService implements OrdersService {
  _FakeOrdersService({this.throwOnCreate = false});
  bool throwOnCreate;
  OrderRecord? createdOrder;

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    if (throwOnCreate) {
      throw OrdersServiceException('boom');
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
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );
    return createdOrder!;
  }

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      Stream<OrderRecord?>.value(null);
}

const _cartItem = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'a.jpg',
  nameProduct: 'Burger',
  price: 10.0,
  quantity: 2,
);

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
            .having((s) => s.error, 'error', contains('boom')),
      ],
    );

    blocTest<OrdersBloc, OrdersState>(
      'updates lastOrder status when a status event arrives',
      build: () => OrdersBloc(ordersService: _FakeOrdersService()),
      seed: () => OrdersState(
        lastOrder: OrderRecord(
          id: 'order-1',
          clientId: 'u',
          addressId: 'a',
          street: '',
          reference: '',
          latitude: 0,
          longitude: 0,
          paymentMethod: 'CASH PAYMENT',
          amount: 10,
          status: OrderRecord.statusPaidOut,
          products: const [],
          createdAt: DateTime(2026, 1, 1),
        ),
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
}