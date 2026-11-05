// End-to-end test of the restaurant (admin) journey.
//
// The test signs in with the restaurant account, opens the dashboard,
// walks into the catalogue management and into the order management, and
// verifies that an order placed by a customer shows up in the restaurant's
// order list.
//
// Everything below the UI is the production code — only Firebase is
// replaced by the in-memory doubles from `helpers/fake_services.dart`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'helpers/app_harness.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Admin journey – end to end', () {
    testWidgets(
      'sign in as the restaurant and land on the dashboard',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.admin());

        // --- ACT: sign in --------------------------------------------------
        await signIn(tester, email: 'admin@delicia.com');

        // --- ASSERT: the dashboard is reachable ----------------------------
        expect(find.text('Bảng điều khiển'), findsWidgets);
        expect(find.text('Doanh thu hôm nay'), findsWidgets);
        expect(find.text('Đơn hàng mới'), findsWidgets);
        expect(find.text('Khách hàng mới'), findsWidgets);
      },
    );

    testWidgets(
      'the dashboard quick actions open the catalogue and the order list',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.admin());
        await signIn(tester, email: 'admin@delicia.com');

        // --- ACT: open the category management ----------------------------
        // The quick-action tiles sit below the fold on a 393 x 852 screen,
        // so the dashboard is scrolled to them first.
        await tester.ensureVisible(find.text('Danh mục'));
        await pumpFrames(tester, frames: 20);
        await tester.tap(find.text('Danh mục'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the category screen is open ---------------------------
        expect(find.text('Quản lý danh mục'), findsWidgets);

        // --- ACT: go back and open the order management --------------------
        await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
        await pumpFrames(tester, frames: 20);
        await tester.ensureVisible(find.text('Đơn hàng'));
        await pumpFrames(tester, frames: 20);
        await tester.tap(find.text('Đơn hàng'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the order management screen is open --------------------
        expect(find.text('Quản lý đơn hàng'), findsWidgets);
      },
    );

    testWidgets(
      "the restaurant sees the order the customer placed",
      (WidgetTester tester) async {
        // --- ARRANGE: a customer places an order ----------------------------
        final customer = await pumpDeliciaApp(tester);
        await signIn(tester);

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

        expect(customer.orderStore.all(), hasLength(1));

        // --- ACT: the restaurant opens the order list ----------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.admin());
        await signIn(tester, email: 'admin@delicia.com');
        await tester.tap(find.text('Đơn hàng'));
        await pumpFrames(tester, frames: 24);

        // --- ASSERT: the order is listed ------------------------------------
        expect(find.text('Burger Nấm Truffle Đặc Trưng'), findsWidgets);
      },
    );

    testWidgets(
      'the catalogue screens list the seeded dishes',
      (WidgetTester tester) async {
        // --- ARRANGE -------------------------------------------------------
        await pumpDeliciaApp(tester, app: IntegrationApp.admin());
        await signIn(tester, email: 'admin@delicia.com');

        // --- ACT: open the product management ------------------------------
        await tester.ensureVisible(find.text('Món ăn'));
        await pumpFrames(tester, frames: 20);
        await tester.tap(find.text('Món ăn'));
        await pumpFrames(tester, frames: 20);

        // --- ASSERT: the seeded products are listed -------------------------
        expect(find.text('Burger Nấm Truffle Đặc Trưng'), findsWidgets);
        expect(find.text('Pizza Phô Mai Chanh Muối'), findsWidgets);
      },
    );
  });
}
