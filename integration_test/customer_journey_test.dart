// End-to-end test of the customer journey.
//
// The test drives the real app: it signs in through the login form,
// browses the catalogue, opens a dish, adds it to the cart, checks out and
// confirms that the order lands in the order history with the right amount.
//
// Everything below the UI is the production code — only Firebase is
// replaced by the in-memory doubles from `helpers/fake_services.dart`.

import 'package:delicia/domain/models/order_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Customer journey – end to end', () {
    testWidgets(
      'sign in, browse the catalogue and open a dish',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester);

        // --- ACT: sign in --------------------------------------------------
        await signIn(tester);

        // --- ASSERT: the home screen is reachable --------------------------
        expect(find.text('Trang chủ'), findsWidgets);
        expect(find.text('Burger Nấm Truffle Đặc Trưng'), findsWidgets);
      },
    );

    testWidgets(
      'add a dish to the cart and open the cart drawer',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester);
        await signIn(tester);

        // --- ACT: open the first dish -------------------------------------
        await tester.tap(find.text('Burger Nấm Truffle Đặc Trưng').first);
        await pumpFrames(tester);

        // --- ASSERT: the detail screen shows the dish ----------------------
        expect(find.text('Thêm vào giỏ hàng'), findsOneWidget);

        // --- ACT: add it to the cart --------------------------------------
        await tester.tap(find.text('Thêm vào giỏ hàng'));
        await pumpFrames(tester);

        // --- ASSERT: the cart drawer shows the line ------------------------
        await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
        await pumpFrames(tester);

        expect(find.text('Thanh toán'), findsOneWidget);
      },
    );

    testWidgets(
      'check out and see the order in the order history',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        final app = await pumpDeliciaApp(tester);
        await signIn(tester);

        // --- ACT: add a dish ----------------------------------------------
        await tester.tap(find.text('Burger Nấm Truffle Đặc Trưng').first);
        await pumpFrames(tester);
        await tester.tap(find.text('Thêm vào giỏ hàng'));
        await pumpFrames(tester);

        // --- ACT: open the cart and check out -----------------------------
        await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
        await pumpFrames(tester);
        await tester.tap(find.text('Thanh toán'));
        await pumpFrames(tester);

        // --- ASSERT: the payment screen is open ---------------------------
        expect(find.text('Thanh toán'), findsWidgets);

        // --- ACT: pay (cash on delivery) ----------------------------------
        await tester.tap(find.text('Thanh toán ngay'));
        await pumpFrames(tester, frames: 24);

        // --- ASSERT: the order was written to the store --------------------
        expect(app.orderStore.all(), hasLength(1));
        final order = app.orderStore.all().first;
        expect(order.status, OrderRecord.statusPaidOut);
        expect(order.paymentMethod, 'CASH PAYMENT');
        expect(order.products, hasLength(1));
        expect(order.products.first.nameProduct,
            'Burger Nấm Truffle Đặc Trưng');

        // The quote travels with the order, so the courier collects exactly
        // what the customer was shown.
        expect(order.quote, isNotNull);
        expect(order.quote!.total, order.amount.round());
      },
    );

    testWidgets(
      'the order history lists the order that was just placed',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        final app = await pumpDeliciaApp(tester);
        await signIn(tester);

        // --- ACT: place an order ------------------------------------------
        await tester.tap(find.text('Burger Nấm Truffle Đặc Trưng').first);
        await pumpFrames(tester);
        await tester.tap(find.text('Thêm vào giỏ hàng'));
        await pumpFrames(tester);
        await tester.tap(find.byIcon(Icons.shopping_bag_rounded));
        await pumpFrames(tester);
        await tester.tap(find.text('Thanh toán'));
        await pumpFrames(tester);
        await tester.tap(find.text('Thanh toán ngay'));
        await pumpFrames(tester, frames: 24);

        // --- ACT: confirm the success modal -------------------------------
        // Placing the order opens the success modal; dismissing it
        // navigates to `/client/orders` on its own.
        await pumpFrames(tester, frames: 20);
        expect(find.text('Đặt món thành công!'), findsOneWidget);
        await tester.tap(find.text('Xong'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the order is listed ------------------------------------
        expect(app.orderStore.all(), hasLength(1));
        expect(find.text('Burger Nấm Truffle Đặc Trưng'), findsWidgets);
      },
    );
  });
}
