// UC-05 — Widget tests for OrderDetailScreen.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/client_orders/client_orders_bloc.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/client_orders_service.dart';
import 'package:delicia/presentation/client/orders/order_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/stub_auth_service.dart';

class _FakeOrdersService implements ClientOrdersService {
  _FakeOrdersService({List<OrderRecord>? initial})
    : orders = List.from(initial ?? const []);

  List<OrderRecord> orders;

  @override
  Future<List<OrderRecord>> listOrdersByClient(String clientId) async => orders;

  @override
  Stream<List<OrderRecord>> watchClientOrders(String clientId) =>
      Stream<List<OrderRecord>>.value(orders);

  @override
  Stream<OrderRecord?> watchOrderUpdates(String orderId) async* {
    final found = orders
        .where((o) => o.id == orderId)
        .cast<OrderRecord?>()
        .firstOrNull;
    yield found;
  }

  @override
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  }) async => throw UnimplementedError();
}

// StubAuthService — delegated to the shared helper in
// test/test_helpers/stub_auth_service.dart.

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}

OrderRecord _build({
  String id = 'o1',
  String status = OrderRecord.statusPaidOut,
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
    amount: 12.5,
    status: status,
    products: const [],
    createdAt: DateTime(2026, 1, 1),
  );
}

void main() {
  testWidgets('renders header, timeline and items for the initial order', (
    tester,
  ) async {
    final initial = _build(id: 'detail1');
    final bloc = ClientOrdersBloc(
      ordersService: _FakeOrdersService(initial: [initial]),
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ClientOrdersBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: auth),
          ],
          // Provide the ClientOrdersService via the repository provider so
          // the detail screen can subscribe to realtime updates.
          child: RepositoryProvider<ClientOrdersService>(
            create: (_) => _FakeOrdersService(initial: [initial]),
            child: OrderDetailScreen(orderId: 'detail1', initialOrder: initial),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PAID OUT'), findsWidgets);
    expect(find.text('DISPATCHED'), findsWidgets);
    expect(find.text('ON WAY'), findsWidgets);
    expect(find.text('DELIVERED'), findsWidgets);
    // The tracking CTA lives below the fold of the detail ListView.
    await tester.scrollUntilVisible(
      find.text('Open live tracking'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Open live tracking'), findsOneWidget);
  });

  testWidgets('shows the cancel button only for cancellable orders', (
    tester,
  ) async {
    final cancelable = _build(id: 'paid');
    final dispatchable = _build(
      id: 'over',
      status: OrderRecord.statusDispatched,
    );
    final bloc = ClientOrdersBloc(
      ordersService: _FakeOrdersService(initial: [cancelable, dispatchable]),
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ClientOrdersBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: auth),
          ],
          child: RepositoryProvider<ClientOrdersService>(
            create: (_) => _FakeOrdersService(initial: [cancelable]),
            child: OrderDetailScreen(orderId: 'paid', initialOrder: cancelable),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cancel this order'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Cancel this order'), findsOneWidget);
  });

  testWidgets('does not show cancel for delivered orders', (tester) async {
    final delivered = _build(
      id: 'delivered',
      status: OrderRecord.statusDelivered,
    );
    final bloc = ClientOrdersBloc(
      ordersService: _FakeOrdersService(initial: [delivered]),
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    addTearDown(bloc.close);
    addTearDown(auth.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<ClientOrdersBloc>.value(value: bloc),
            BlocProvider<AuthBloc>.value(value: auth),
          ],
          child: RepositoryProvider<ClientOrdersService>(
            create: (_) => _FakeOrdersService(initial: [delivered]),
            child: OrderDetailScreen(
              orderId: 'delivered',
              initialOrder: delivered,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cancel this order'), findsNothing);
  });
}
