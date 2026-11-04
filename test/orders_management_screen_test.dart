// UC-09 — AdminOrdersManagementScreen widget test.
//
// The screen is driven by the [AdminOrdersBloc], which is fed by the
// admin orders service. The test asserts:
//
//   1. the order rows render (product, amount, status pill),
//   2. the status filter chips really filter,
//   3. the empty state shows up when there is no order.

import 'package:delicia/domain/models/delivery_user.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/presentation/admin/orders/orders_management_screen.dart';
import 'package:delicia/presentation/admin/orders/widgets/assign_delivery_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/pump_helpers.dart';

OrderRecord _order({
  required String id,
  String name = 'Burger',
  String status = OrderRecord.statusPaidOut,
  double amount = 10,
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
        price: amount,
        quantity: 1,
      ),
    ],
    createdAt: DateTime(2026, 3, 10),
  );
}

/// Mounts the orders screen with the fake service.
Widget _harness(AdminOrdersService ordersService) {
  return RepositoryProvider<AdminOrdersService>.value(
    value: ordersService,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminOrdersManagementScreen(),
    ),
  );
}

void main() {
  testWidgets('renders one row per order', (WidgetTester tester) async {
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(id: 'o1', name: 'Burger', amount: 12),
        _order(id: 'o2', name: 'Pizza', amount: 30),
      ],
    );

    await tester.pumpWidget(_harness(orders));
    await settleAdmin(tester);

    expect(find.text('Quản lý đơn hàng'), findsOneWidget);
    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    // The status filter chips.
    expect(find.text('Tất cả'), findsWidgets);
    expect(find.text('Chờ xử lý'), findsWidgets);
    expect(find.text('Hoàn tất'), findsWidgets);
  });

  testWidgets('the filter chips narrow the list', (WidgetTester tester) async {
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(id: 'o1', name: 'Burger'),
        _order(id: 'o2', name: 'Pizza', status: OrderRecord.statusDelivered),
      ],
    );

    await tester.pumpWidget(_harness(orders));
    await settleAdmin(tester);

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);

    // Filter down to the completed orders.
    await tester.tap(find.text('Hoàn tất').first);
    await settleAdmin(tester);

    expect(find.text('Burger'), findsNothing);
    expect(find.text('Pizza'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no order', (
    WidgetTester tester,
  ) async {
    final orders = FakeAdminOrdersService();

    await tester.pumpWidget(_harness(orders));
    await settleAdmin(tester);

    expect(find.text('Chưa có đơn hàng nào'), findsOneWidget);
  });

  testWidgets('the assign-delivery dialog only lists the enabled drivers', (
    WidgetTester tester,
  ) async {
    final order = _order(id: 'o1');

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                AssignDeliveryDialog.show(
                  context,
                  order: order,
                  drivers: const <DeliveryUser>[
                    DeliveryUser(uid: 'd1', name: 'Tài xế A', isEnabled: true),
                    DeliveryUser(uid: 'd2', name: 'Tài xế B', isEnabled: false),
                  ],
                  onAssign: (_) {},
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await settleAdmin(tester);

    expect(find.byType(AssignDeliveryDialog), findsOneWidget);
    expect(find.text('Tài xế A'), findsOneWidget);
    expect(find.text('Tài xế B'), findsNothing);
  });
}
