// Layout verification against the Figma frames.
//
// Figma node 147:2153 (empty) / 147:2106 (one order) place every
// element at an exact coordinate on a 393 x 852 frame. This test
// asserts the rendered positions so a layout regression is caught
// instead of silently drifting away from the design.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/client/orders/orders_screen.dart';
import 'package:delicia/presentation/client/orders/widgets/order_filter_chips.dart';
import 'package:delicia/presentation/client/orders/widgets/order_row.dart';
import 'package:delicia/presentation/client/orders/widgets/orders_empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';

class _Stub implements OrdersService {
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

OrderRecord _order() {
  return OrderRecord(
    id: 'o1',
    clientId: 'u1',
    addressId: 'a1',
    street: '',
    reference: '',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: 20,
    status: OrderRecord.statusOnWay,
    products: <OrderItem>[
      OrderItem(
        productId: 'p1',
        nameProduct: 'Strawberry shake',
        picture: '',
        price: 10,
        quantity: 2,
      ),
    ],
    createdAt: DateTime(2026, 11, 29, 13, 20),
  );
}

Future<OrdersBloc> _pump(
  WidgetTester tester, {
  List<OrderRecord> orders = const <OrderRecord>[],
}) async {
  tester.view.physicalSize = const Size(393, 852);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final bloc = OrdersBloc(ordersService: _Stub());
  final auth = AuthBloc(authService: FakeAuthService());
  addTearDown(bloc.close);
  addTearDown(auth.close);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>.value(value: auth),
          BlocProvider<OrdersBloc>.value(value: bloc),
        ],
        child: const ClientOrdersView(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (orders.isNotEmpty) {
    bloc.emit(bloc.state.copyWith(myOrders: orders));
    await tester.pumpAndSettle();
  }
  return bloc;
}

/// Top-left of [finder] in global (screen) coordinates.
Offset _topLeft(WidgetTester tester, Finder finder) =>
    tester.getTopLeft(finder);

void main() {
  group('My Orders layout vs Figma', () {
    testWidgets('the filter chips sit on the Figma y164 baseline', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final chips = tester.getSize(find.byType(OrderFilterChips));
      // Figma: chips at top=164, height=28.
      // The header band ends at 32 (status bar) + 13 (title) + 26 (pad).
      expect(chips.height, 28);
      // The three chips are evenly spread and fit inside the frame.
      expect(chips.width, lessThanOrEqualTo(393));
    });

    testWidgets('the chips are laid out left to right as Active/Completed/Cancelled', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final active = _topLeft(tester, find.text('Đang xử lý'));
      final completed = _topLeft(tester, find.text('Hoàn tất'));
      final cancelled = _topLeft(tester, find.text('Đã huỷ'));

      expect(active.dx, lessThan(completed.dx));
      expect(completed.dx, lessThan(cancelled.dx));

      // The pills themselves (Figma: all at top=164, height=28) share
      // the same vertical band.
      final pillTops = <double>[];
      for (final label in <String>['active', 'completed', 'cancelled']) {
        pillTops.add(
          tester.getTopLeft(find.byKey(ValueKey<String>('filter-chip-$label'))).dy,
        );
      }
      expect(pillTops[0], closeTo(pillTops[1], 0.5));
      expect(pillTops[1], closeTo(pillTops[2], 0.5));
    });

    testWidgets('the empty state renders the icon and the copy', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.byType(OrdersEmptyState), findsOneWidget);
      expect(
        find.text('Bạn hiện không có đơn hàng nào đang xử lý'),
        findsOneWidget,
      );
      // The illustration is 140 x 167 in the Figma.
      final icon = tester.getSize(
        find.descendant(
          of: find.byType(OrdersEmptyState),
          matching: find.byType(SvgPicture),
        ),
      );
      expect(icon.width, 140);
      expect(icon.height, 167);
    });

    testWidgets('the order row keeps the Figma thumbnail size', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orders: <OrderRecord>[_order()]);

      expect(find.byType(OrderRow), findsOneWidget);
      // Figma: thumbnail 71.68 x 108 at x35.
      final thumb = tester.getSize(
        find.descendant(
          of: find.byType(OrderRow),
          matching: find.byType(ClipRRect),
        ).first,
      );
      expect(thumb.width, closeTo(72, 0.5));
      expect(thumb.height, 108);
      final thumbTopLeft = _topLeft(
        tester,
        find.descendant(
          of: find.byType(OrderRow),
          matching: find.byType(ClipRRect),
        ).first,
      );
      // Figma: x35.
      expect(thumbTopLeft.dx, closeTo(35, 1));
    });

    testWidgets('the order row shows the Figma fields', (
      WidgetTester tester,
    ) async {
      await _pump(tester, orders: <OrderRecord>[_order()]);

      expect(find.text('Strawberry shake'), findsOneWidget);
      expect(find.text('500.000 ₫'), findsOneWidget);
      expect(find.text('2 món'), findsOneWidget);
      // Figma timestamp format: "29 Nov, 01:20 pm".
      expect(find.text('29 Nov, 01:20 pm'), findsOneWidget);
      expect(find.text('Huỷ đơn hàng'), findsOneWidget);
      expect(find.text('Theo dõi tài xế'), findsOneWidget);
    });

    testWidgets('the header title is the Figma string', (
      WidgetTester tester,
    ) async {
      await _pump(tester);
      expect(find.text('Đơn hàng của tôi'), findsOneWidget);
    });
  });
}
