// Overflow regression tests for the My Orders screen.
//
// The order rows mix a fixed-height thumbnail (108 px) with a text
// column, and the empty state stacks a 167 px illustration with a 30 px
// headline. Both have to survive small phones and large text.

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

class _StubOrdersService implements OrdersService {
  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) =>
      Stream<List<OrderRecord>>.value(const <OrderRecord>[]);

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
    throw OrdersServiceException('not used');
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
}

OrderRecord _order({
  required String id,
  String status = OrderRecord.statusOnWay,
  String name = 'Strawberry shake',
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
    amount: 20,
    status: status,
    products: <OrderItem>[
      OrderItem(
        productId: 'p1',
        nameProduct: name,
        picture: '',
        price: 10,
        quantity: 2,
      ),
    ],
    createdAt: DateTime(2026, 11, 29, 13, 20),
  );
}

Future<void> _pumpOrders(
  WidgetTester tester, {
  required OrdersBloc bloc,
  Size size = const Size(393, 852),
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final authBloc = AuthBloc(authService: FakeAuthService());
  addTearDown(authBloc.close);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: authBloc),
          BlocProvider<OrdersBloc>.value(value: bloc),
        ],
        child: const ClientOrdersView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // The order row mixes a fixed-width thumbnail with a text column, so the
  // text has to be measured with the real font — the placeholder font that
  // `flutter_test` ships makes every glyph a full-width box and reports a
  // false overflow on the (longer) Vietnamese price string.
  setUpAll(loadAppFonts);

  group('My Orders screen overflow', () {
    const sizes = <Size>[
      Size(320, 640),
      Size(360, 640),
      Size(393, 852),
      Size(412, 915),
      Size(360, 800),
    ];

    for (final size in sizes) {
      testWidgets('empty state does not overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        WidgetTester tester,
      ) async {
        final bloc = OrdersBloc(ordersService: _StubOrdersService());
        addTearDown(bloc.close);
        await _pumpOrders(tester, bloc: bloc, size: size);
        expect(tester.takeException(), isNull);
      });

      testWidgets('order list does not overflow at ${size.width.toInt()}x${size.height.toInt()}', (
        WidgetTester tester,
      ) async {
        final bloc = OrdersBloc(ordersService: _StubOrdersService());
        addTearDown(bloc.close);
        await _pumpOrders(tester, bloc: bloc, size: size);
        bloc.emit(
          bloc.state.copyWith(
            myOrders: <OrderRecord>[
              _order(id: 'o1'),
              _order(id: 'o2', name: 'A very long product name that will not fit'),
            ],
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('no overflow with 1.8x text scale', (WidgetTester tester) async {
      final bloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(bloc.close);
      await _pumpOrders(tester, bloc: bloc, textScale: 1.8);
      bloc.emit(
        bloc.state.copyWith(
          myOrders: <OrderRecord>[_order(id: 'o1')],
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}
