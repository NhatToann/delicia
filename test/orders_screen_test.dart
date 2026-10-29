// Widget tests for the My Orders screen (Figma 147:2153 / 147:2106).
//
// The screen is driven entirely by [OrdersBloc], so the tests seed the
// bloc state directly and assert what the user sees:
//   1. Empty state per filter (Figma 4.1.1 - B).
//   2. Order list rendering (Figma 4.1.1 - C).
//   3. The Active / Completed / Cancelled chips actually filter.
//   4. The header (title + back arrow) renders.

import 'dart:async';

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/client/orders/orders_screen.dart';
import 'package:delicia/presentation/client/orders/widgets/order_filter_chips.dart';
import 'package:delicia/presentation/client/orders/widgets/order_row.dart';
import 'package:delicia/presentation/client/orders/widgets/orders_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';

class _StubOrdersService implements OrdersService {
  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) =>
      Stream<List<OrderRecord>>.value(const <OrderRecord>[]);

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      Stream<OrderRecord?>.value(null);

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    throw OrdersServiceException('not used');
  }

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
}

OrderRecord _order({
  required String id,
  String status = OrderRecord.statusOnWay,
  String name = 'Strawberry shake',
  double amount = 20.0,
  int quantity = 2,
  DateTime? createdAt,
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
        price: 10,
        quantity: quantity,
      ),
    ],
    createdAt: createdAt ?? DateTime(2026, 11, 29, 13, 20),
  );
}

Widget _harness({
  required OrdersBloc ordersBloc,
  required AuthBloc authBloc,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<OrdersBloc>.value(value: ordersBloc),
      ],
      child: const ClientOrdersView(),
    ),
  );
}

void main() {
  group('ClientOrdersView — header', () {
    testWidgets('renders the title and a back affordance', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(
        authService: FakeAuthService(
          user: const User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'John',
            lastName: 'Smith',
            rolId: 2,
          ),
        ),
      )..emit(const AuthState(
          user: User(
            uid: 'u1',
            email: 'a@b.com',
            firstName: 'John',
            lastName: 'Smith',
            rolId: 2,
          ),
        ));
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đơn hàng của tôi'), findsOneWidget);
      expect(find.bySemanticsLabel('Quay lại'), findsOneWidget);
      // The three chips are always present.
      expect(find.byType(OrderFilterChips), findsOneWidget);
    });
  });

  group('ClientOrdersView — empty state', () {
    testWidgets('shows the Figma empty copy for the active filter', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(authService: FakeAuthService());
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(find.byType(OrdersEmptyState), findsOneWidget);
      expect(
        find.text('Bạn hiện không có đơn hàng nào đang xử lý'),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the empty copy follows the selected filter', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(authService: FakeAuthService());
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      // Switch to Completed.
      await tester.tap(find.bySemanticsLabel('Hoàn tất bộ lọc'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bạn hiện không có đơn hàng hoàn tất nào'),
        findsOneWidget,
      );
      expect(
        find.text('Bạn hiện không có đơn hàng nào đang xử lý'),
        findsNothing,
      );

      // Switch to Cancelled.
      await tester.tap(find.bySemanticsLabel('Đã huỷ bộ lọc'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn hiện không có đơn hàng đã huỷ nào'),
        findsOneWidget,
      );
      handle.dispose();
    });
  });

  group('ClientOrdersView — order list', () {
    testWidgets('renders an order row with its product, count and price', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService())
        ..emit(
          const OrdersState().copyWith(
            myOrders: <OrderRecord>[],
          ),
        );
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(authService: FakeAuthService());
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();

      // Now push an order through the bloc so the list reacts.
      ordersBloc.emit(
        ordersBloc.state.copyWith(
          myOrders: <OrderRecord>[_order(id: 'o1')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(OrderRow), findsOneWidget);
      expect(find.text('Strawberry shake'), findsOneWidget);
      expect(find.text('2 món'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsOneWidget);
      expect(find.text('Huỷ đơn hàng'), findsOneWidget);
      expect(find.text('Theo dõi tài xế'), findsOneWidget);
    });

    testWidgets('the chips filter the visible orders', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(authService: FakeAuthService());
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      ordersBloc.emit(
        ordersBloc.state.copyWith(
          myOrders: <OrderRecord>[
            _order(id: 'active', status: OrderRecord.statusOnWay),
            _order(
              id: 'done',
              status: OrderRecord.statusDelivered,
              name: 'Completed dish',
            ),
            _order(
              id: 'void',
              status: OrderRecord.statusCancelled,
              name: 'Cancelled dish',
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Active filter shows only the in-flight order.
      expect(find.byType(OrderRow), findsOneWidget);
      expect(find.text('Strawberry shake'), findsOneWidget);

      // Completed shows the delivered one.
      await tester.tap(find.bySemanticsLabel('Hoàn tất bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderRow), findsOneWidget);
      expect(find.text('Completed dish'), findsOneWidget);
      expect(find.text('Strawberry shake'), findsNothing);

      // Cancelled shows the void one.
      await tester.tap(find.bySemanticsLabel('Đã huỷ bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderRow), findsOneWidget);
      expect(find.text('Cancelled dish'), findsOneWidget);
      expect(find.text('Completed dish'), findsNothing);
      handle.dispose();
    });

    testWidgets('a filter with no matching orders shows the empty state', (
      WidgetTester tester,
    ) async {
      final ordersBloc = OrdersBloc(ordersService: _StubOrdersService());
      addTearDown(ordersBloc.close);
      final authBloc = AuthBloc(authService: FakeAuthService());
      addTearDown(authBloc.close);

      await tester.pumpWidget(
        _harness(ordersBloc: ordersBloc, authBloc: authBloc),
      );
      await tester.pumpAndSettle();
      final handle = tester.ensureSemantics();

      ordersBloc.emit(
        ordersBloc.state.copyWith(
          myOrders: <OrderRecord>[
            _order(id: 'active', status: OrderRecord.statusOnWay),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(OrderRow), findsOneWidget);

      // Nothing was ever completed → empty state for that chip.
      await tester.tap(find.bySemanticsLabel('Hoàn tất bộ lọc'));
      await tester.pumpAndSettle();
      expect(find.byType(OrderRow), findsNothing);
      expect(find.byType(OrdersEmptyState), findsOneWidget);
      handle.dispose();
    });
  });
}
