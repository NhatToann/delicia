// Geometry regression test for the My Orders screen.
//
// Figma node 147:2106 ("4.1.1 - C - My Orders - Active") pins every
// element to an exact coordinate on a 393 x 852 frame. This test
// asserts the rendered positions so a layout change can't silently
// drift away from the design.
//
// The frame includes a 32 px system status bar, which the test
// reproduces via `tester.view.padding` so the absolute Figma
// coordinates apply directly.

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

OrderRecord _order() {
  return OrderRecord(
    id: 'o1',
    clientId: 'u1',
    addressId: 'a1',
    street: '',
    reference: '',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: 20,
    status: OrderRecord.statusPaidOut,
    products: <OrderItem>[
      OrderItem(
        productId: 'p1',
        nameProduct: 'Strawberry shake',
        picture: '',
        price: 10,
        quantity: 2,
      ),
    ],
    createdAt: DateTime(2026, 11, 29, 13, 20),
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  // The Figma frame includes a 32 px iOS-style status bar.
  tester.view.padding = const FakeViewPadding(top: 32);
  tester.view.viewPadding = const FakeViewPadding(top: 32);
  addTearDown(tester.view.reset);

  final bloc = OrdersBloc(ordersService: _Stub());
  final auth = AuthBloc(authService: FakeAuthService());
  addTearDown(bloc.close);
  addTearDown(auth.close);

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
  bloc.emit(bloc.state.copyWith(myOrders: <OrderRecord>[_order()]));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('My Orders geometry vs Figma 147:2106', () {
    testWidgets('the title sits at y73 and is centred', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final title = find.text('Đơn hàng của tôi');
      final tl = tester.getTopLeft(title);
      expect(tl.dy, closeTo(73, 1));
      // Figma: the title is centred on the 393 px frame.
      final size = tester.getSize(title);
      expect(tl.dx + size.width / 2, closeTo(196.5, 2));
    });

    testWidgets('the back arrow sits at x35 / y81', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final arrow = find.bySemanticsLabel('Quay lại');
      final tl = tester.getTopLeft(arrow);
      final size = tester.getSize(arrow);
      expect(tl.dx, closeTo(35, 1));
      expect(tl.dy, closeTo(81, 1));
      expect(size.width, 8);
      expect(size.height, 13);
    });

    testWidgets('the chip row starts at y164 and is 28 px tall', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final pill = find.byKey(const ValueKey<String>('filter-chip-active'));
      final tl = tester.getTopLeft(pill);
      expect(tl.dy, closeTo(164, 1));
      expect(tester.getSize(pill).height, 28);
      // Figma: the three pills span x35 → x358.
      final first = tester.getTopLeft(pill).dx;
      final last = tester.getTopRight(
        find.byKey(const ValueKey<String>('filter-chip-cancelled')),
      ).dx;
      expect(first, closeTo(35, 1));
      expect(last, closeTo(358, 1));
    });

    testWidgets('the thumbnail sits at x35 / y222 and is 72 x 108', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final thumb = find.byType(ClipRRect).first;
      final tl = tester.getTopLeft(thumb);
      final size = tester.getSize(thumb);
      expect(tl.dx, closeTo(35, 1));
      expect(tl.dy, closeTo(222, 1));
      expect(size.width, closeTo(72, 0.5));
      expect(size.height, 108);
    });

    testWidgets('the order title, meta and price sit on the Figma rows', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // Title — Figma x120, y242.
      final title = tester.getTopLeft(find.text('Strawberry shake'));
      expect(title.dx, closeTo(120, 1));
      expect(title.dy, closeTo(242, 1));

      // Price — Figma right-aligned at x358, y242.
      final price = tester.getTopRight(find.text('500.000 ₫'));
      expect(price.dx, closeTo(358, 1));
      expect(tester.getTopLeft(find.text('500.000 ₫')).dy, closeTo(242, 1));

      // Meta row — Figma y269.
      expect(tester.getTopLeft(find.text('2 món')).dy, closeTo(269, 1));
    });

    testWidgets('the action buttons sit on the Figma y288 row', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // The pill is 26 px tall and the label is vertically centred in
      // it, so the label lands 3 px lower than the pill's top edge.
      final cancel = tester.getTopLeft(find.text('Huỷ đơn hàng'));
      expect(cancel.dy, closeTo(288 + 3, 2));
      // Figma: the Cancel Order pill starts at x118 — the label itself
      // starts 12 px later, after the pill's horizontal padding.
      expect(cancel.dx, closeTo(118 + 12, 2));
    });
  });
}
