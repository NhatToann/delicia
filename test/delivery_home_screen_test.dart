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
import 'package:delicia/presentation/helpers/money.dart';
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
  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) =>
      Stream.value(const []);

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}
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

  Widget createWidgetUnderTest({
    List<OrderRecord>? assignedOrders,
    List<OrderRecord>? availableOrders,
    OrderRecord? notification,
  }) {
    if (assignedOrders != null) {
      fakeOrdersService.assignedOrders = assignedOrders;
    }
    if (availableOrders != null) {
      fakeOrdersService.availableOrders = availableOrders;
    }
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
      assignedOrders: assignedOrders ?? [sampleAssignedOrder],
      availableOrders: availableOrders ?? [sampleAvailableOrder],
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

  testWidgets('DeliveryHomeScreen renders tabs and assigned orders in Vietnamese with VND', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify Tab headers
    expect(find.text('Đơn đang giao'), findsOneWidget);
    expect(find.text('Đơn chờ nhận'), findsOneWidget);
    expect(find.text('Thu nhập'), findsOneWidget);

    // Verify Driver Name & Online Status
    expect(find.text('Alex Driver'), findsOneWidget);
    expect(find.text('Online & Sẵn sàng'), findsOneWidget);

    // Verify assigned order card is visible with VND
    expect(find.text('789 Elm Street'), findsOneWidget);
    expect(find.text(Money.format(19.99)), findsOneWidget);
    expect(find.text('Đã nhận đơn'), findsOneWidget); // DISPATCHED maps to Đã nhận đơn
    expect(find.text('Bản đồ'), findsOneWidget);
    expect(find.text('Đã giao'), findsOneWidget);
    expect(find.text('Nhận được: '), findsOneWidget);
    expect(find.text('Từ chối'), findsNothing); // Reject is removed once accepted
  });

  testWidgets('DeliveryHomeScreen shows confirmation dialog when Đã giao is tapped on assigned order', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap "Đã giao" on the assigned order card
    await tester.tap(find.text('Đã giao'));
    await tester.pumpAndSettle();

    // Verify dialog appears
    expect(find.text('Xác nhận đã giao'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
    expect(find.text('Xác nhận'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen switches to Available Orders tab and shows available order when no active delivery', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      assignedOrders: const [],
      availableOrders: [sampleAvailableOrder],
    ));
    await tester.pumpAndSettle();

    // Tap "Đơn chờ nhận" tab
    await tester.tap(find.text('Đơn chờ nhận'));
    await tester.pumpAndSettle();

    // Verify available order card has both Nhận đơn and Từ chối with VND
    expect(find.text('100 Beach Road'), findsOneWidget);
    expect(find.text(Money.format(32.50)), findsOneWidget);
    expect(find.text('Nhận đơn'), findsOneWidget);
    expect(find.text('Từ chối'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen hides available orders when driver has an active order', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      assignedOrders: [sampleAssignedOrder], // Active delivery
      availableOrders: const [], // Hidden when active
    ));
    await tester.pumpAndSettle();

    // Tap "Đơn chờ nhận" tab
    await tester.tap(find.text('Đơn chờ nhận'));
    await tester.pumpAndSettle();

    // Verify available orders are hidden and message is shown
    expect(find.text('Đang có đơn hàng cần giao'), findsOneWidget);
    expect(find.text('100 Beach Road'), findsNothing);
  });

  testWidgets('DeliveryHomeScreen shows reject confirmation dialog when Từ chối is tapped on available order', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      assignedOrders: const [],
      availableOrders: [sampleAvailableOrder],
    ));
    await tester.pumpAndSettle();

    // Tap "Đơn chờ nhận" tab
    await tester.tap(find.text('Đơn chờ nhận'));
    await tester.pumpAndSettle();

    // Tap Từ chối
    await tester.tap(find.text('Từ chối'));
    await tester.pumpAndSettle();

    // Verify dialog appears in Vietnamese
    expect(find.text('Từ chối đơn hàng'), findsOneWidget);
    expect(find.text('Hủy'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen displays notification banner when new order arrives in Vietnamese with VND', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest(
      assignedOrders: const [],
      notification: sampleAvailableOrder,
    ));
    await tester.pumpAndSettle();

    expect(find.text('Có đơn hàng mới!'), findsOneWidget);
    expect(find.text('Xem'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen renders Earnings tab with distance-based 90% shipping fee calculation', (tester) async {
    final deliveredOrder1 = OrderRecord(
      id: 'ord-deliv-1',
      clientId: 'c1',
      addressId: 'a1',
      street: '123 Le Loi, Ben Nghe',
      reference: 'Near park',
      latitude: 10.758,
      longitude: 106.7009,
      paymentMethod: 'CASH PAYMENT',
      amount: 25.00,
      status: OrderRecord.statusDelivered,
      deliveryId: 'driver-test-uid',
      deliveryName: 'Alex Driver',
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(createWidgetUnderTest(
      assignedOrders: [deliveredOrder1],
      availableOrders: const [],
    ));
    await tester.pumpAndSettle();

    // Switch to Thu nhập tab
    await tester.tap(find.text('Thu nhập'));
    await tester.pumpAndSettle();

    // Verify Earnings content
    expect(find.text('Tổng thu nhập tích lũy'), findsOneWidget);
    expect(find.text('Chính sách thu nhập & Phí ship'), findsOneWidget);
    expect(find.text('Tỷ lệ tài xế nhận'), findsOneWidget);
    expect(find.text('90% (Dưới 1 km: 5.000 ₫)'), findsOneWidget);
    expect(find.text('Đã hoàn thành 1 đơn hàng'), findsOneWidget);
    expect(find.text('123 Le Loi, Ben Nghe'), findsOneWidget);
    expect(find.text('Từ 1 - 3 km'), findsOneWidget);
    expect(find.text('5.000 ₫ / km'), findsOneWidget);
    expect(find.text('Từ 3 - 8 km'), findsOneWidget);
    expect(find.text('8.000 ₫ / km'), findsOneWidget);
    expect(find.text('Trên 8 km'), findsOneWidget);
    expect(find.text('10.000 ₫ / km'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen renders Trang cá nhân tab and displays profile info matching client profile style', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify Tab header for Trang cá nhân is visible
    expect(find.text('Trang cá nhân'), findsOneWidget);

    // Switch to Trang cá nhân tab
    await tester.tap(find.text('Trang cá nhân'));
    await tester.pumpAndSettle();

    // Verify Profile header and fields
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('Tài xế Delicia • Đang hoạt động'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Alex Driver'), findsWidgets);
    expect(find.text('Ngày sinh'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('driver@delicia.com'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Vai trò tài khoản'), findsOneWidget);
    expect(find.text('Tài xế giao hàng (Driver)'), findsOneWidget);
    expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
  });

  testWidgets('DeliveryHomeScreen switches to Trang cá nhân when profile icon in AppBar is tapped', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Tap profile icon button in AppBar
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();

    // Verify profile is displayed
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('Tài xế giao hàng (Driver)'), findsOneWidget);
  });
}
