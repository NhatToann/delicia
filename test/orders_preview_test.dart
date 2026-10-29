// Renders the My Orders screen to PNGs so the layout can be compared
// against the Figma frames (147:2153 empty / 147:2106 with one order).
//
// Run with:  flutter test test/orders_preview_test.dart --update-goldens

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/client/orders/orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';
import 'helpers/load_fonts.dart';

class _Stub implements OrdersService {
  @override
  Stream<List<OrderRecord>> watchMyOrders(String c) =>
      Stream<List<OrderRecord>>.value(const <OrderRecord>[]);
  @override
  Future<OrderRecord?> getOrder(String id) async => null;
  @override
  Stream<OrderRecord?> watchOrder(String id) => Stream<OrderRecord?>.value(null);
  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async =>
      throw OrdersServiceException('x');
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
}

OrderRecord _order({
  required String id,
  String status = OrderRecord.statusOnWay,
  String name = 'Strawberry shake',
  double amount = 20,
  int qty = 2,
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
    products: <OrderItem>[
      OrderItem(
        productId: 'p1',
        nameProduct: name,
        picture: '',
        price: 10,
        quantity: qty,
      ),
    ],
    createdAt: DateTime(2026, 11, 29, 13, 20),
  );
}

Future<void> _render(
  WidgetTester tester,
  List<OrderRecord> orders,
  String name,
) async {
  final bloc = OrdersBloc(ordersService: _Stub());
  final auth = AuthBloc(authService: FakeAuthService());
  addTearDown(bloc.close);
  addTearDown(auth.close);

  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<OrdersBloc>.value(value: bloc),
        ],
        child: const ClientOrdersView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  bloc.emit(bloc.state.copyWith(myOrders: orders));
  await tester.pumpAndSettle();
  // Let the product thumbnails finish decoding before capturing.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 200)),
  );
  await tester.pumpAndSettle();

  await expectLater(
    find.byType(ClientOrdersView),
    matchesGoldenFile('goldens/orders_$name.png'),
  );
}

void main() {
  setUpAll(bootstrapGolden);

  testWidgets('orders preview — empty', (WidgetTester tester) async {
    await _render(tester, const <OrderRecord>[], 'empty');
  });

  testWidgets('orders preview — one active order', (WidgetTester tester) async {
    await _render(tester, <OrderRecord>[_order(id: 'o1')], 'active');
  });

  testWidgets('orders preview — three orders', (WidgetTester tester) async {
    await _render(
      tester,
      <OrderRecord>[
        _order(id: 'o1', name: 'Strawberry shake', amount: 20),
        _order(id: 'o2', name: 'Classic burger', amount: 34.5, qty: 3),
        _order(id: 'o3', name: 'Cold lemonade', amount: 12, qty: 1),
      ],
      'list',
    );
  });
}
