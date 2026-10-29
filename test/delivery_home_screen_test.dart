import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/delivery/delivery_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/delivery/home/delivery_home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOrdersService implements OrdersService {
  List<OrderRecord> assignedOrders = [];
  List<OrderRecord> availableOrders = [];

  @override
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId) async =>
      assignedOrders;

  @override
  Future<List<OrderRecord>> getAvailableOrders() async => availableOrders;

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) =>
      Stream.value(assignedOrders);

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() =>
      Stream.value(availableOrders);

  @override
  Future<void> acceptOrder(String orderId, String deliveryId, {String? deliveryName}) async {}

  @override
  Future<void> rejectOrder(String orderId, String deliveryId) async {}

  @override
  Future<void> updateDeliveryStatus(String orderId, String newStatus, {String? deliveryPhoto}) async {}

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async =>
      throw UnimplementedError();

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<OrderRecord?> watchOrder(String id) => Stream.value(null);
}

void main() {
  late _FakeOrdersService fakeOrdersService;

  final sampleAssignedOrder = OrderRecord(
    id: 'ord-assign-1',
    clientId: 'c1',
    addressId: 'a1',
    street: '789 Elm Street',
    reference: 'Gate B',
    latitude: 10.77,
    longitude: 106.70,
    paymentMethod: 'CASH PAYMENT',
    amount: 19.99,
    status: 'DISPATCHED',
    deliveryId: 'driver-test-uid',
    deliveryName: 'Alex Driver',
    products: const [],
    createdAt: DateTime(2026, 1, 1),
  );

  final sampleAvailableOrder = OrderRecord(
    id: 'ord-avail-1',
    clientId: 'c2',
    addressId: 'a2',
    street: '100 Beach Road',
    reference: 'Opposite mall',
    latitude: 10.78,
    longitude: 106.71,
    paymentMethod: 'CASH PAYMENT',
    amount: 32.50,
    status: 'PAID OUT',
    products: const [],
    createdAt: DateTime(2026, 1, 1),
  );

  setUp(() {
    fakeOrdersService = _FakeOrdersService()
      ..assignedOrders = [sampleAssignedOrder]
      ..availableOrders = [sampleAvailableOrder];
  });

  Widget createWidgetUnderTest({OrderRecord? notification}) {
    final authBloc = AuthBloc(authService: _FakeAuthService());
    authBloc.emit(const AuthState(
      user: User(
        uid: 'driver-test-uid',
        email: 'driver@delicia.com',
        firstName: 'Alex',
        lastName: 'Driver',
        rolId: 3,
      ),
    ));

    final deliveryBloc = DeliveryBloc(ordersService: fakeOrdersService);
    deliveryBloc.emit(DeliveryState(
      assignedOrders: [sampleAssignedOrder],
      availableOrders: [sampleAvailableOrder],
      newOrderNotification: notification,
    ));

    final ordersBloc = OrdersBloc(ordersService: fakeOrdersService);

    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<DeliveryBloc>.value(value: deliveryBloc),
        BlocProvider<OrdersBloc>.value(value: ordersBloc),
      ],
      child: const MaterialApp(
        home: DeliveryHomeScreen(),
      ),
    );
  }

  testWidgets('DeliveryHomeScreen renders tabs and assigned orders', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify Tab headers
    expect(find.text('My Deliveries'), findsOneWidget);
    expect(find.text('Available Orders'), findsOneWidget);

    // Verify Driver Name & Online Status
    expect(find.text('Alex Driver'), findsOneWidget);
    expect(find.text('Online & Ready'), findsOneWidget);

    // Verify assigned order card is visible
    expect(find.text('789 Elm Street'), findsOneWidget);
    expect(find.text('\$19.99'), findsOneWidget);
    expect(find.text('Accepted'), findsOneWidget); // DISPATCHED maps to Accepted
  });

  testWidgets('DeliveryHomeScreen switches to Available Orders tab and shows available order', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap "Available Orders" tab
    await tester.tap(find.text('Available Orders'));
    await tester.pumpAndSettle();

    // Verify available order card
    expect(find.text('100 Beach Road'), findsOneWidget);
    expect(find.text('\$32.50'), findsOneWidget);
    expect(find.text('Accept Order'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen displays notification banner when new order arrives', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(notification: sampleAvailableOrder));
    await tester.pumpAndSettle();

    expect(find.text('New Order Assigned!'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);
  });
}
