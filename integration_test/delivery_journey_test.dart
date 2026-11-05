// End-to-end test of the courier (delivery) journey.
//
// The test signs in with the courier account, picks an order up from the
// "available orders" tab, drives the delivery state machine forward and
// checks that the earnings tab adds up.
//
// Everything below the UI is the production code — only Firebase is
// replaced by the in-memory doubles from `helpers/fake_services.dart`.

import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_harness.dart';

/// A paid order waiting for a courier, with no driver assigned yet.
OrderRecord _pendingOrder() {
  final now = DateTime.now();
  return OrderRecord(
    id: 'order-seed-1',
    clientId: 'uid-1',
    clientName: 'Nguyễn Test',
    clientEmail: 'khach@delicia.com',
    addressId: 'addr-1',
    street: '1 Lê Lợi, Bến Nghé',
    reference: 'Quận 1, TP. Hồ Chí Minh',
    latitude: 10.7769,
    longitude: 106.7009,
    paymentMethod: 'CASH PAYMENT',
    amount: 113250,
    status: OrderRecord.statusPaidOut,
    distanceKm: 2.4,
    createdAt: now,
    placedAt: now.millisecondsSinceEpoch,
    products: const <OrderItem>[
      OrderItem(
        productId: 'p01',
        nameProduct: 'Burger Nấm Truffle Đặc Trưng',
        picture: 'assets/products/burger.png',
        price: 89000,
        quantity: 1,
      ),
    ],
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Delivery journey – end to end', () {
    testWidgets(
      'sign in as the courier and land on the delivery home',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.delivery());

        // --- ACT: sign in --------------------------------------------------
        await signIn(tester, email: 'taixe@delicia.com');

        // --- ASSERT: the delivery home is reachable ------------------------
        expect(find.text('Đơn đang giao'), findsWidgets);
        expect(find.text('Đơn chờ nhận'), findsWidgets);
        expect(find.text('Thu nhập'), findsWidgets);
        expect(find.text('Trang cá nhân'), findsWidgets);
      },
    );

    testWidgets(
      'the courier sees the empty state when no order is available',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.delivery());
        await signIn(tester, email: 'taixe@delicia.com');

        // --- ACT: open the "available orders" tab --------------------------
        await tester.tap(find.text('Đơn chờ nhận'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the empty state is shown ------------------------------
        expect(find.text('Hiện không có đơn hàng khả dụng'), findsOneWidget);
      },
    );

    testWidgets(
      'the courier accepts an available order and it moves to the active tab',
      (WidgetTester tester) async {
        // --- ARRANGE: an order is waiting for a courier ---------------------
        final app = await pumpDeliciaApp(tester, app: IntegrationApp.delivery());
        app.orderStore.put(_pendingOrder());
        await signIn(tester, email: 'taixe@delicia.com');

        // --- ACT: open the "available orders" tab --------------------------
        await tester.tap(find.text('Đơn chờ nhận'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the order is listed -----------------------------------
        expect(find.text('1x Burger Nấm Truffle Đặc Trưng'), findsWidgets);

        // --- ACT: accept the order ------------------------------------------
        await tester.tap(find.text('Nhận đơn'));
        await pumpFrames(tester, frames: 24);

        // --- ASSERT: the order is now assigned to the courier ---------------
        final accepted = app.orderStore.all().first;
        expect(accepted.status, OrderRecord.statusDispatched);
        expect(accepted.deliveryUserId, isNotEmpty);

        // --- ASSERT: the active tab shows the order ------------------------
        expect(find.text('Đơn đang giao'), findsWidgets);
        expect(find.text('1x Burger Nấm Truffle Đặc Trưng'), findsWidgets);
      },
    );

    testWidgets(
      'the courier confirms the delivery and the earnings tab adds up',
      (WidgetTester tester) async {
        // --- ARRANGE: an order is waiting for a courier ---------------------
        final app = await pumpDeliciaApp(tester, app: IntegrationApp.delivery());
        app.orderStore.put(_pendingOrder());
        await signIn(tester, email: 'taixe@delicia.com');

        // --- ACT: accept the order ------------------------------------------
        await tester.tap(find.text('Đơn chờ nhận'));
        await pumpFrames(tester, frames: 20);
        await tester.tap(find.text('Nhận đơn'));
        await pumpFrames(tester, frames: 24);

        // --- ACT: confirm the delivery --------------------------------------
        await tester.tap(find.text('Đã giao'));
        await pumpFrames(tester, frames: 20);
        expect(find.text('Xác nhận đã giao'), findsOneWidget);
        await tester.tap(find.text('Xác nhận'));
        await pumpFrames(tester, frames: 24);

        // --- ASSERT: the order is delivered ---------------------------------
        final delivered = app.orderStore.all().first;
        expect(delivered.status, OrderRecord.statusDelivered);

        // --- ACT: open the earnings tab -------------------------------------
        await tester.tap(find.text('Thu nhập'));
        await pumpFrames(tester, frames: 24);

        // --- ASSERT: the earnings add up -------------------------------------
        expect(find.text('Tổng thu nhập tích lũy'), findsOneWidget);
        expect(find.text('Đã hoàn thành 1 đơn hàng'), findsOneWidget);
      },
    );
  });
}
