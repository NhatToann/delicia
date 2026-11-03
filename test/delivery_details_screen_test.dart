import 'package:delicia/domain/bloc/delivery/delivery_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/delivery/details/delivery_details_screen.dart';
import 'package:delicia/presentation/helpers/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeOrdersService implements OrdersService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) =>
      Stream.value(const []);

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() =>
      Stream.value(const []);
}

void main() {
  final sampleOrder = OrderRecord(
    id: 'ord-detail-99',
    clientId: 'client-abc',
    addressId: 'addr-1',
    street: '55 Nguyen Hue Blvd, D1',
    reference: 'Floor 12, Unit 1205',
    latitude: 10.773,
    longitude: 106.703,
    paymentMethod: 'CASH ON DELIVERY',
    amount: 18.50,
    status: 'DISPATCHED', // Maps to DeliveryStatus.accepted
    receiverName: 'Nguyen Van A',
    receiverPhone: '0909123456',
    products: const [
      OrderItem(
        productId: 'prod-1',
        nameProduct: 'Crispy Fried Chicken',
        picture: 'assets/products/burger-classic.jpg',
        price: 9.25,
        quantity: 2,
      ),
    ],
    createdAt: DateTime(2026, 1, 1, 14, 30),
  );

  Widget createWidgetUnderTest() {
    final fakeOrdersService = _FakeOrdersService();
    final deliveryBloc = DeliveryBloc(ordersService: fakeOrdersService);
    deliveryBloc.emit(DeliveryState(assignedOrders: [sampleOrder]));

    final ordersBloc = OrdersBloc(ordersService: fakeOrdersService);

    return MultiBlocProvider(
      providers: [
        BlocProvider<DeliveryBloc>.value(value: deliveryBloc),
        BlocProvider<OrdersBloc>.value(value: ordersBloc),
      ],
      child: MaterialApp(
        home: DeliveryDetailsScreen(
          orderId: sampleOrder.id,
          order: sampleOrder,
        ),
      ),
    );
  }

  testWidgets('DeliveryDetailsScreen displays customer contact, address, items, and action button in Vietnamese with VND',
      (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify Customer Contact
    expect(find.text('Nguyen Van A'), findsOneWidget);
    expect(find.text('0909123456'), findsOneWidget);
    expect(find.byIcon(Icons.phone), findsOneWidget);
    expect(find.byIcon(Icons.message), findsOneWidget);

    // Verify Address
    expect(find.text('55 Nguyen Hue Blvd, D1'), findsOneWidget);
    expect(find.text('Ghi chú: Floor 12, Unit 1205'), findsOneWidget);
    expect(find.text('Bản đồ'), findsOneWidget);

    // Verify Ordered Item with VND formatting
    expect(find.text('Crispy Fried Chicken'), findsOneWidget);
    expect(find.text('2 x ${Money.format(9.25)}'), findsOneWidget);
    expect(find.text(Money.format(18.50)), findsNWidgets(2)); // Item subtotal + Total due
    expect(find.text('Phần tiền nhận được'), findsOneWidget);

    // Verify Action Button for Accepted status: next step is Confirm Picked Up in Vietnamese
    expect(find.text('Xác nhận đã lấy hàng tại quán'), findsOneWidget);
  });
}
