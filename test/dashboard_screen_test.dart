// UC-07 — AdminDashboardScreen widget test.
//
// The dashboard is driven by the [DashboardBloc], which in turn is fed by
// the admin order / customer services. The test mounts the screen with
// the fakes and asserts what the restaurant actually sees:
//
//   1. the three stat tiles,
//   2. the seven-day chart card,
//   3. the recent-orders widget,
//   4. the quick-action shortcuts.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/models/customer_account.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/presentation/admin/dashboard/dashboard_screen.dart';
import 'package:delicia/presentation/admin/dashboard/widgets/recent_orders.dart';
import 'package:delicia/presentation/admin/dashboard/widgets/revenue_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/fake_auth_service.dart';
import 'helpers/pump_helpers.dart';

/// The "now" the dashboard is pinned to.
final DateTime _now = DateTime(2026, 3, 10, 14, 30);

OrderRecord _order({
  required String id,
  String name = 'Burger',
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
    createdAt: _now,
  );
}

/// Mounts the dashboard with the fake services.
Widget _harness({
  required AdminOrdersService ordersService,
  required AdminUsersService usersService,
}) {
  return MultiRepositoryProvider(
    providers: <RepositoryProvider<dynamic>>[
      RepositoryProvider<AdminOrdersService>.value(value: ordersService),
      RepositoryProvider<AdminUsersService>.value(value: usersService),
    ],
    child: BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authService: FakeAuthService())
        ..emit(const AuthState(
          user: User(
            uid: 'a1',
            email: 'admin@delicia.vn',
            firstName: 'Quản trị',
            lastName: 'Viên',
            rolId: 1,
          ),
        )),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: AdminDashboardScreen(),
      ),
    ),
  );
}

/// Gives the test a tall viewport so the whole dashboard is laid out.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('shows the stat tiles, the chart and the quick actions', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[_order(id: 'o1', amount: 25)],
    );
    final users = FakeAdminUsersService(
      customers: <CustomerAccount>[
        CustomerAccount(
          uid: 'c1',
          name: 'Nguyễn A',
          createdAt: DateTime(2026, 3, 10, 8),
        ),
      ],
    );

    await tester.pumpWidget(
      _harness(ordersService: orders, usersService: users),
    );
    await settleAdmin(tester);

    // The three stat tiles.
    expect(find.text('Doanh thu hôm nay'), findsOneWidget);
    expect(find.text('Đơn hàng mới'), findsOneWidget);
    expect(find.text('Khách hàng mới'), findsOneWidget);

    // The seven-day chart card.
    expect(find.text('Doanh thu 7 ngày'), findsOneWidget);
    expect(find.text('Số đơn 7 ngày'), findsOneWidget);
    expect(find.byType(RevenueChart), findsOneWidget);
    expect(find.byType(OrderCountChart), findsOneWidget);

    // The recent-orders widget and the quick actions.
    expect(find.byType(RecentOrders), findsOneWidget);
    expect(find.text('Thao tác nhanh'), findsOneWidget);
    expect(find.text('Danh mục'), findsOneWidget);
    expect(find.text('Món ăn'), findsOneWidget);
    expect(find.text('Đơn hàng'), findsOneWidget);
    expect(find.text('Tài xế'), findsOneWidget);
  });

  testWidgets('renders the recent orders that arrived on the stream', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);
    final orders = FakeAdminOrdersService(
      orders: <OrderRecord>[
        _order(id: 'o1', name: 'Burger', amount: 12),
        _order(id: 'o2', name: 'Pizza', amount: 30),
      ],
    );

    await tester.pumpWidget(
      _harness(ordersService: orders, usersService: FakeAdminUsersService()),
    );
    await settleAdmin(tester);

    expect(find.text('Burger'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    // The status pill of a paid order.
    expect(find.byType(AdminStatusPill), findsWidgets);
  });

  testWidgets('shows the empty copy when there is no order at all', (
    WidgetTester tester,
  ) async {
    _useTallViewport(tester);
    final orders = FakeAdminOrdersService();

    await tester.pumpWidget(
      _harness(ordersService: orders, usersService: FakeAdminUsersService()),
    );
    await settleAdmin(tester);

    expect(find.byType(RecentOrders), findsOneWidget);
    expect(find.text('Chưa có đơn hàng nào'), findsOneWidget);
  });
}
