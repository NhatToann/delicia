// Geometry regression test for the Payment screen.
//
// Figma node 202:2956 ("4.3 - D - Payment") pins every element to an exact
// coordinate on a 393 x 852 frame. This test asserts the rendered positions
// so a layout change can't silently drift away from the design.
//
// The frame includes a 32 px system status bar, which the test reproduces
// via `tester.view.padding` so the absolute Figma coordinates apply
// directly.
//
// The expectations are the *ink* boxes measured off the Figma PNG
// (`assets/.../4.3 - D - Payment.png`), not the node boxes: Figma's
// text nodes carry a leading that is often taller than the node, so the
// glyphs sit outside the node's own box.
import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/bloc/payment/payment_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/domain/services/payment_gateway.dart';
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
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async =>
      throw OrdersServiceException('x');
  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
}

class _StubGateway implements PaymentGateway {
  @override
  String get name => 'stub';
  @override
  Future<PaymentLink> createPaymentLink({
    required double amount,
    required String orderCode,
    required String description,
    required List<ProductCart> products,
    required String returnUrl,
    required String cancelUrl,
    required String? buyerEmail,
    required String? buyerName,
  }) async =>
      const PaymentLink(url: 'https://example.test/pay', reference: 'r1');
  @override
  Future<PaymentResult> queryStatus(String reference) async =>
      const PaymentResult(status: PaymentStatus.paid, amount: 1000);
}

const ProductCart _shake = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'assets/figma_home/card_best_1.png',
  nameProduct: 'Strawberry Shake',
  price: 20.00,
  quantity: 2,
);

const ProductCart _lasagna = ProductCart(
  uidProduct: 'p2',
  imageProduct: 'assets/figma_home/card_best_2.png',
  nameProduct: 'Broccoli Lasagna',
  price: 20.00,
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
  final payment = PaymentBloc(gateway: _StubGateway());
  addTearDown(cart.close);
  addTearDown(orders.close);
  addTearDown(auth.close);
  addTearDown(payment.close);

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
          BlocProvider<PaymentBloc>.value(value: payment),
        ],
        child: const PaymentScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadAppFonts);

  group('Payment geometry vs Figma 202:2956', () {
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

    testWidgets('the address card sits at x35 / y209 and is 323 x 35', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final card = find.byType(InkWell).at(0);
      final tl = tester.getTopLeft(card);
      expect(tl.dx, closeTo(35, 1));
      expect(tl.dy, closeTo(209, 1));
      expect(tester.getSize(card).width, closeTo(323, 1));
      expect(tester.getSize(card).height, closeTo(35, 1));
    });

    testWidgets('the section titles sit on the Figma rows', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Figma draws "Order Summary" at y291, "Payment Method" at y397 and
      // "Delivery Time" at y499 — each node's own box is 14 px tall and
      // centred on a taller line box, so the glyphs sit above the node.
      expect(tester.getTopLeft(find.text('Tóm tắt đơn hàng')).dy, closeTo(291, 1));
      expect(
        tester.getTopLeft(find.text('Phương thức thanh toán')).dy,
        closeTo(397, 1),
      );
      expect(tester.getTopLeft(find.text('Thời gian giao hàng')).dy, closeTo(499, 1));
    });

    testWidgets('the shipping address title sits at x46 / y166', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Figma's node box starts at y172 and is 14 px tall, but its 26 px
      // leading overflows the box symmetrically — so the line box starts at
      // y166 and the glyphs at y168.
      final tl = tester.getTopLeft(find.text('Địa chỉ giao hàng'));
      expect(tl.dx, closeTo(46, 1));
      expect(tl.dy, closeTo(166, 1));
    });

    testWidgets('the item rows sit on the Figma rows', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Figma: "Strawberry Shake" at x35 / y322, "2 items" right-aligned
      // so it ends at x189, and the price at x295 / y328.
      final name = tester.getTopLeft(find.text('Strawberry Shake'));
      expect(name.dx, closeTo(35, 1));
      expect(name.dy, closeTo(322, 1));

      final qty = tester.getTopLeft(find.text('2 món'));
      expect(qty.dy, closeTo(322, 1));
      expect(
        qty.dx + tester.getSize(find.text('2 món')).width,
        closeTo(189, 1),
      );

      final price = tester.getTopLeft(find.text('1.000.000 ₫'));
      expect(price.dx, closeTo(295, 1));
      expect(price.dy, closeTo(328, 1));
    });

    testWidgets('the payment method row sits on the Figma row', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      // Figma: the method name is at x75, y431.
      final name = tester.getTopLeft(find.text('THANH TOÁN TIỀN MẶT').first);
      expect(name.dx, closeTo(75, 1));
      expect(name.dy, closeTo(431, 1));
    });

    testWidgets('the delivery estimate shows the configured minutes', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Giao hàng dự kiến'), findsOneWidget);
      expect(find.text('25 phút'), findsOneWidget);
      final value = tester.getTopLeft(find.text('25 phút'));
      expect(value.dx, closeTo(292, 1));
      expect(value.dy, closeTo(529, 1));
    });

    testWidgets('the Pay Now button is 157 x 38 at x123 / y717', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      final button = find.bySemanticsLabel('Thanh toán ngay');
      final size = tester.getSize(button);
      expect(size.width, closeTo(157.43, 1));
      expect(size.height, closeTo(38, 1));
      final tl = tester.getTopLeft(button);
      expect(tl.dx, closeTo(123.29, 1));
      expect(tl.dy, closeTo(717, 1));
    });

    testWidgets('the summary lists both products with their prices', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Strawberry Shake'), findsOneWidget);
      expect(find.text('Broccoli Lasagna'), findsOneWidget);
      // Two items of the shake at $20 each.
      expect(find.text('1.000.000 ₫'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsOneWidget);
    });

    testWidgets('the total is derived from the cart', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Tổng cộng'), findsOneWidget);
      // $60 of food + 5 % tax + the flat delivery fee.
      expect(find.text('1.637.500 ₫'), findsOneWidget);
    });
  });
}
