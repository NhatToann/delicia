// UC-05 — Widget tests for OrdersListScreen.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/client_orders/client_orders_bloc.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/client_orders_service.dart';
import 'package:delicia/presentation/client/orders/orders_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/stub_auth_service.dart';

class _FakeOrdersService implements ClientOrdersService {
  _FakeOrdersService({List<OrderRecord>? orders}) : orders = orders ?? [];
  List<OrderRecord> orders;
  bool cancelCalled = false;

  @override
  Future<List<OrderRecord>> listOrdersByClient(String clientId) async => orders;

  @override
  Stream<List<OrderRecord>> watchClientOrders(String clientId) =>
      Stream<List<OrderRecord>>.value(orders);

  @override
  Stream<OrderRecord?> watchOrderUpdates(String orderId) =>
      Stream<OrderRecord?>.value(null);

  @override
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    cancelCalled = true;
    return OrderRecord(
      id: orderId,
      clientId: 'user-1',
      addressId: 'a',
      street: '',
      reference: '',
      latitude: 0,
      longitude: 0,
      paymentMethod: 'CASH PAYMENT',
      amount: 10,
      status: ClientOrderStatuses.cancelled,
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );
  }
}

OrderRecord _buildOrder({
  required String id,
  String status = OrderRecord.statusPaidOut,
  double amount = 10,
  DateTime? createdAt,
}) {
  return OrderRecord(
    id: id,
    clientId: 'user-1',
    addressId: 'a',
    street: '$id street',
    reference: 'District',
    latitude: 10,
    longitude: 106,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: status,
    products: const [],
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

Widget _wrap({
  required _FakeOrdersService ordersService,
  required ClientOrdersBloc bloc,
  required AuthBloc authBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<ClientOrdersBloc>.value(value: bloc),
        BlocProvider<AuthBloc>.value(value: authBloc),
      ],
      child: const OrdersListScreen(),
    ),
  );
}

/// Drives [AuthBloc] to its authenticated state so the screens can resolve
/// a uid. Two pump() calls are needed: the first lets the event resolve in the
/// bloc, the second lets the BlocListener&lt;AuthBloc&gt; fire its post-frame
/// load.
Future<void> seedAuth(WidgetTester tester, AuthBloc auth) async {
  auth.add(CheckLoginEvent());
  await tester.pump();
  await tester.pump();
}

/// Let microtasks (stream emissions, async service returns) settle
/// without using `pumpAndSettle` — the fake services use
/// `Stream.value(...)` whose emissions never end, so pumpAndSettle
/// would hang.
Future<void> settleMicrotasks(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('renders a populated list of active orders', (tester) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final ordersService = _FakeOrdersService(
      orders: [
        _buildOrder(id: 'alpha', status: OrderRecord.statusOnWay, amount: 25),
        _buildOrder(id: 'beta', status: OrderRecord.statusDispatched),
      ],
    );
    final bloc = ClientOrdersBloc(ordersService: ordersService);
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      _wrap(ordersService: ordersService, bloc: bloc, authBloc: auth),
    );
    // Auth → BlocListener → postFrame → ClientOrdersBloc Load + Subscribe
    await seedAuth(tester, auth);
    // Async listOrdersByClient resolves + stream emits
    await settleMicrotasks(tester);

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.textContaining('Order #alpha'), findsOneWidget);
    expect(find.textContaining('Order #beta'), findsOneWidget);
    expect(find.text('ON WAY'), findsOneWidget);
    expect(find.text('DISPATCHED'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no orders', (tester) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final ordersService = _FakeOrdersService();
    final bloc = ClientOrdersBloc(ordersService: ordersService);
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      _wrap(ordersService: ordersService, bloc: bloc, authBloc: auth),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    expect(find.text('No active orders'), findsOneWidget);
    expect(find.text('Start Shopping'), findsOneWidget);
  });

  testWidgets('switches to history tab and shows delivered/cancelled items', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final ordersService = _FakeOrdersService(
      orders: [
        _buildOrder(id: 'past1', status: OrderRecord.statusDelivered),
        _buildOrder(id: 'past2', status: ClientOrderStatuses.cancelled),
      ],
    );
    final bloc = ClientOrdersBloc(ordersService: ordersService);
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      _wrap(ordersService: ordersService, bloc: bloc, authBloc: auth),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    await tester.tap(find.text('History'));
    // PageView tab animation needs multiple animation frames.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Order #past1'), findsOneWidget);
    expect(find.textContaining('Order #past2'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  testWidgets('cancel button is shown for PAID OUT orders only', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final ordersService = _FakeOrdersService(
      orders: [
        _buildOrder(id: 'a1', status: OrderRecord.statusPaidOut),
        _buildOrder(id: 'a2', status: OrderRecord.statusOnWay),
        _buildOrder(id: 'a3', status: OrderRecord.statusDelivered),
      ],
    );
    final bloc = ClientOrdersBloc(ordersService: ordersService);
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      _wrap(ordersService: ordersService, bloc: bloc, authBloc: auth),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    // PAID OUT card has Cancel.
    final cancelButton = find.text('Cancel');
    expect(cancelButton, findsOneWidget);
  });

  // Regression: the screen used to kick off its initial load from a
  // BlocListener<AuthBloc> that only fires when the uid *changes*. When the
  // user was already signed in before opening the screen (the real-world
  // case), the listener never fired and the list stayed empty until the
  // user hit the refresh button. The load must now happen on first build.
  testWidgets('loads orders on first build when already signed in', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final ordersService = _FakeOrdersService(
      orders: [
        _buildOrder(id: 'pre1', status: OrderRecord.statusPaidOut),
        _buildOrder(id: 'pre2', status: OrderRecord.statusDelivered),
      ],
    );
    final bloc = ClientOrdersBloc(ordersService: ordersService);
    addTearDown(bloc.close);
    addTearDown(auth.close);

    // Auth is resolved BEFORE the screen is ever built — this is the
    // "already logged in" scenario that used to show an empty list.
    await seedAuth(tester, auth);

    await tester.pumpWidget(
      _wrap(ordersService: ordersService, bloc: bloc, authBloc: auth),
    );
    await settleMicrotasks(tester);

    expect(find.textContaining('Order #pre1'), findsOneWidget);
    expect(find.text('No active orders'), findsNothing);
  });
}
