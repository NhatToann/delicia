// UC-07 / UC-09 — AdminNewOrdersScreen widget test.
//
// The "Đơn hàng mới" screen is what the dashboard's new-orders tile
// opens. It answers the restaurant's first question of the day: *who
// just ordered, what did they order, and when?*
//
// The test mounts the screen with the fake order service and asserts:
//
//   1. the orders of the current day are listed,
//   2. each row shows the customer who placed the order,
//   3. the range switch reveals the older orders too,
//   4. the empty state shows when nothing came in.

import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/presentation/admin/dashboard/widgets/recent_orders.dart';
import 'package:delicia/presentation/admin/orders/new_orders_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/pump_helpers.dart';

/// An order placed by [clientName] at [createdAt].
OrderRecord _order({
  required String id,
  required String clientName,
  required DateTime createdAt,
  String clientEmail = '',
  String name = 'Burger',
  double amount = 12,
}) {
  return OrderRecord(
    id: id,
    clientId: 'u-$id',
    clientName: clientName,
    clientEmail: clientEmail,
    addressId: 'a1',
    street: 'Baker Street',
    reference: 'Flat 3',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: OrderRecord.statusPaidOut,
    products: <OrderItem>[
      OrderItem(
        productId: 'p1',
        nameProduct: name,
        picture: '',
        price: amount,
        quantity: 1,
      ),
    ],
    createdAt: createdAt,
  );
}

/// Mounts the screen with the fake order service.
Widget _harness({required AdminOrdersService ordersService}) {
  return RepositoryProvider<AdminOrdersService>.value(
    value: ordersService,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminNewOrdersScreen(),
    ),
  );
}

void main() {
  testWidgets('lists the orders placed today with their customer', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(
          id: 'o1',
          clientName: 'Nguyễn Văn A',
          clientEmail: 'a@delicia.vn',
          createdAt: now.subtract(const Duration(minutes: 12)),
        ),
      ],
    );

    await tester.pumpWidget(_harness(ordersService: orders));
    await settleAdmin(tester);

    // The order the customer just placed.
    expect(find.text('Burger'), findsOneWidget);
    // The customer who placed it.
    expect(find.text('Nguyễn Văn A'), findsOneWidget);
    expect(find.text('a@delicia.vn'), findsOneWidget);
    // The status pill.
    expect(find.byType(AdminStatusPill), findsOneWidget);
  });

  testWidgets('hides the orders of the previous days until the range flips', (
    WidgetTester tester,
  ) async {
    final now = DateTime.now();
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(
          id: 'o1',
          clientName: 'Khách Hôm Nay',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        _order(
          id: 'o2',
          clientName: 'Khách Hôm Qua',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
      ],
    );

    await tester.pumpWidget(_harness(ordersService: orders));
    await settleAdmin(tester);

    expect(find.text('Khách Hôm Nay'), findsOneWidget);
    expect(find.text('Khách Hôm Qua'), findsNothing);

    // Flip to "all orders".
    await tester.tap(find.text('Tất cả đơn hàng'));
    await settleAdmin(tester);

    expect(find.text('Khách Hôm Nay'), findsOneWidget);
    expect(find.text('Khách Hôm Qua'), findsOneWidget);
  });

  testWidgets('shows the empty copy when no order came in today', (
    WidgetTester tester,
  ) async {
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(
          id: 'o1',
          clientName: 'Khách Hôm Qua',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
        ),
      ],
    );

    await tester.pumpWidget(_harness(ordersService: orders));
    await settleAdmin(tester);

    expect(find.text('Chưa có đơn hàng mới nào'), findsOneWidget);
  });

  testWidgets('falls back to an anonymous customer when the name is missing', (
    WidgetTester tester,
  ) async {
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(
          id: 'o1',
          clientName: '',
          createdAt: DateTime.now(),
        ),
      ],
    );

    await tester.pumpWidget(_harness(ordersService: orders));
    await settleAdmin(tester);

    expect(find.text('Khách ẩn danh'), findsOneWidget);
  });
}
