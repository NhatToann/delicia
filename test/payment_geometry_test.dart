// Geometry regression test for the Payment screen.
//
// Figma node 202:2956 ("4.3 - D - Payment") is the reference design, but
// the screen has grown past the static frame: it now carries a voucher
// block and an itemised money breakdown, so its body can no longer be
// pinned to fixed Figma coordinates (the number of rows is dynamic).
//
// The contract this file protects is therefore split in two:
//
//   * the **chrome** — the yellow header band, the title and the back
//     chevron — stays on its exact Figma coordinates, because it never
//     moves; and
//   * the **body** — the sheet and everything in it — keeps the design's
//     horizontal rhythm (a 24 px gutter, a right-aligned money column,
//     a pinned CTA) and stays in reading order.
//
// The frame includes a 32 px system status bar, which the test reproduces
// via `tester.view.padding` so the absolute Figma coordinates apply
// directly.
import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/price_breakdown.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/client/payment/payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';
import 'helpers/load_fonts.dart';

class _StubOrders implements OrdersService {
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
    required String clientName,
    required String clientEmail,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
    PriceBreakdown? quote,
    double distanceKm = 0.0,
    String? receiverPhone,
    String? receiverName,
  }) async =>
      throw OrdersServiceException('x');
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
  @override
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId) async => const [];

  @override
  Future<List<OrderRecord>> getAvailableOrders() async => const [];

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) => Stream.value(const []);

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() => Stream.value(const []);

  @override
  Future<void> acceptOrder(String orderId, String deliveryId, {String? deliveryName}) async {}

  @override
  Future<void> rejectOrder(String orderId, String deliveryId) async {}

  @override
  Future<void> updateDeliveryStatus(String orderId, String newStatus, {String? deliveryPhoto, bool cashCollected = false, int? collectedAmountVnd}) async {}
}

const ProductCart _shake = ProductCart(
    uidProduct: 'p1',
  imageProduct: 'assets/figma_home/card_best_1.png',
  nameProduct: 'Strawberry Shake',
  price: 500000,
  quantity: 2,
);

const ProductCart _lasagna = ProductCart(
  uidProduct: 'p2',
  imageProduct: 'assets/figma_home/card_best_2.png',
  nameProduct: 'Broccoli Lasagna',
  price: 500000,
  quantity: 1,
);

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  // The Figma frame includes a 32 px status bar.
  tester.view.padding = const FakeViewPadding(top: 32);
  tester.view.viewPadding = const FakeViewPadding(top: 32);
  addTearDown(tester.view.reset);

  final cart = CartBloc();
  final orders = OrdersBloc(ordersService: _StubOrders());
  final auth = AuthBloc(authService: FakeAuthService());
  addTearDown(cart.close);
  addTearDown(orders.close);
  addTearDown(auth.close);

  cart.add(const OnAddProductToCartEvent(_shake));
  cart.add(const OnAddProductToCartEvent(_lasagna));

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<CartBloc>.value(value: cart),
          BlocProvider<OrdersBloc>.value(value: orders),
        ],
        child: const PaymentScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('Payment header vs Figma 202:2956', () {
    testWidgets('the title sits at y73 and is centred', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final title = find.text('Thanh toán');
      final tl = tester.getTopLeft(title);
      expect(tl.dy, closeTo(73, 1));
      final size = tester.getSize(title);
      expect(tl.dx + size.width / 2, closeTo(196.5, 2));
    });

    testWidgets('the back arrow sits at x35 / y81', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final arrow = find.bySemanticsLabel('Quay lại');
      final tl = tester.getTopLeft(arrow);
      expect(tl.dx, closeTo(35, 1));
      expect(tl.dy, closeTo(81, 1));
      expect(tester.getSize(arrow).width, 8);
      expect(tester.getSize(arrow).height, 13);
    });

    testWidgets('the yellow band ends at y132 and the sheet starts there', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // The band covers the 32 px status bar plus 100 px of content.
      final sheet = find.byType(Container).first;
      expect(tester.getTopLeft(sheet).dy, closeTo(132, 1));
    });
  });

  group('Payment body layout contract', () {
    testWidgets('the content keeps the 24 px gutter on both sides', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final heading = find.text('Địa chỉ giao hàng');
      expect(tester.getTopLeft(heading).dx, closeTo(24, 1));

      // The address card spans the full content width: 393 - 2 * 24.
      // It is located through its own label, because the header's back
      // arrow is an InkWell too.
      final card = find
          .ancestor(
            of: find.text('1 Lê Lợi, Bến Nghé'),
            matching: find.byType(Material),
          )
          .first;
      expect(tester.getTopLeft(card).dx, closeTo(24, 1));
      expect(tester.getSize(card).width, closeTo(345, 1));
    });

    testWidgets('the sections keep the Figma reading order', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final order = <double>[
        tester.getTopLeft(find.text('Địa chỉ giao hàng')).dy,
        tester.getTopLeft(find.text('Tóm tắt đơn hàng')).dy,
        tester.getTopLeft(find.text('Phương thức thanh toán')).dy,
        tester.getTopLeft(find.text('Thời gian giao hàng')).dy,
      ];
      // Every section sits below the previous one.
      for (var i = 1; i < order.length; i++) {
        expect(order[i], greaterThan(order[i - 1]));
      }
    });

    testWidgets('the item rows keep the price column right-aligned', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // The item name sits on the 24 px gutter ...
      final name = tester.getTopLeft(find.text('Strawberry Shake'));
      expect(name.dx, closeTo(24, 1));

      // ... and the price ends on the right margin (393 - 24).
      final price = tester.getTopRight(find.text('1.000.000 ₫'));
      expect(price.dx, closeTo(369, 1));
    });

    testWidgets('the delivery estimate shows the configured minutes', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Giao hàng dự kiến'), findsOneWidget);
      expect(find.text('25 phút'), findsOneWidget);
      // The value is right-aligned on the content's right edge.
      final value = tester.getTopRight(find.text('25 phút'));
      expect(value.dx, closeTo(369, 1));
    });

    testWidgets('the Pay Now button is pinned above the navigation bar', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final button = find.bySemanticsLabel('Thanh toán ngay');
      final size = tester.getSize(button);
      // The CTA spans the content width and keeps a comfortable height.
      expect(size.width, closeTo(345, 1));
      expect(size.height, closeTo(52, 1));

      // It sits above the 64 px navigation bar, so its bottom edge is at
      // 852 - 64 - 16 = 772.
      final bottom = tester.getBottomLeft(button).dy;
      expect(bottom, closeTo(772, 1));
    });

    testWidgets('the summary lists both products with their prices', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Strawberry Shake'), findsOneWidget);
      expect(find.text('Broccoli Lasagna'), findsOneWidget);
      expect(find.text('1.000.000 ₫'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsOneWidget);
    });

    testWidgets('the breakdown itemises the money and the total matches', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Tổng cộng'), findsOneWidget);
      // 1 500 000 ₫ of food + 5 % tax (75 000) + the flat 25 000 delivery fee.
      expect(find.text('1.600.000 ₫'), findsOneWidget);
      // The breakdown shows every component, not just the total.
      expect(find.text('Phí giao hàng'), findsOneWidget);
    });

    testWidgets('the body scrolls instead of overflowing', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });
  });
}
