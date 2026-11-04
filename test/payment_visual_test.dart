// Visual check for the Payment screen.
//
// Renders Figma "4.3 - D - Payment" at the frame's exact size so the
// result can be compared pixel-by-pixel against
// `assets/Food Delivery App UI Kit .../4.3 - D - Payment.png`.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/price_breakdown.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/models/type_payment.dart';
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
  Future<void> updateDeliveryStatus(String orderId, String newStatus, {String? deliveryPhoto}) async {}

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

void main() {
  setUpAll(loadAppFonts);

  testWidgets('payment screen (4.3 - D)', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1.0;
    tester.view.padding = const FakeViewPadding(top: 32);
    tester.view.viewPadding = const FakeViewPadding(top: 32);
    addTearDown(tester.view.reset);

    final cart = CartBloc()
      ..add(const OnAddProductToCartEvent(_shake))
      ..add(const OnAddProductToCartEvent(_lasagna));
    final orders = OrdersBloc(ordersService: _StubOrders());
    final auth = AuthBloc(authService: FakeAuthService());
      addTearDown(cart.close);
    addTearDown(orders.close);
    addTearDown(auth.close);
  
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<CartBloc>.value(value: cart),
            BlocProvider<OrdersBloc>.value(value: orders),
            ],
          child: PaymentScreen(
            // The Figma frame shows the credit-card method, so the golden
            // render reproduces that rather than the app's default (cash).
            initialMethod: typePaymentMethods.firstWhere(
              (m) => m.uid == 'CREDIT_CARD',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(PaymentScreen),
      matchesGoldenFile('payment_render.png'),
    );
  });
}
