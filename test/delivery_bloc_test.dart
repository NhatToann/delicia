import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/delivery/delivery_bloc.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/delivery_status.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _MockOrdersService implements OrdersService {
  List<OrderRecord> assignedOrders = [];
  List<OrderRecord> availableOrders = [];
  bool throwError = false;

  @override
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId) async {
    if (throwError) throw OrdersServiceException('Failed to fetch assigned');
    return assignedOrders;
  }

  @override
  Future<List<OrderRecord>> getAvailableOrders() async {
    if (throwError) throw OrdersServiceException('Failed to fetch available');
    return availableOrders;
  }

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) =>
      Stream.value(assignedOrders);

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() =>
      Stream.value(availableOrders);

  @override
  Future<void> acceptOrder(String orderId, String deliveryId, {String? deliveryName}) async {
    if (throwError) throw OrdersServiceException('Failed to accept');
    final match = availableOrders.firstWhere((o) => o.id == orderId);
    availableOrders.removeWhere((o) => o.id == orderId);
    assignedOrders.add(match.copyWith(
      deliveryId: deliveryId,
      deliveryName: deliveryName,
      status: 'DISPATCHED',
    ));
  }

  @override
  Future<void> rejectOrder(String orderId, String deliveryId) async {
    if (throwError) throw OrdersServiceException('Failed to reject');
    assignedOrders.removeWhere((o) => o.id == orderId);
  }

  @override
  Future<void> updateDeliveryStatus(String orderId, String newStatus, {String? deliveryPhoto}) async {
    if (throwError) throw OrdersServiceException('Failed to update status');
    final index = assignedOrders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      assignedOrders[index] = assignedOrders[index].copyWith(
        status: newStatus,
        deliveryPhoto: deliveryPhoto,
      );
    }
  }

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async {
    throw UnimplementedError();
  }

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
  late _MockOrdersService mockService;
  late OrderRecord testOrder1;
  late OrderRecord testOrder2;

  setUp(() {
    mockService = _MockOrdersService();
    testOrder1 = OrderRecord(
      id: 'order-101',
      clientId: 'c1',
      addressId: 'a1',
      street: '123 Main St',
      reference: 'Near park',
      latitude: 10.77,
      longitude: 106.70,
      paymentMethod: 'CASH PAYMENT',
      amount: 25.50,
      status: 'DISPATCHED',
      deliveryId: 'driver-1',
      deliveryName: 'John Driver',
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );
    testOrder2 = OrderRecord(
      id: 'order-102',
      clientId: 'c2',
      addressId: 'a2',
      street: '456 Second St',
      reference: 'Apt 4B',
      latitude: 10.78,
      longitude: 106.71,
      paymentMethod: 'CASH PAYMENT',
      amount: 40.00,
      status: 'PAID OUT',
      products: const [],
      createdAt: DateTime(2026, 1, 1),
    );
  });

  group('DeliveryBloc Tests (UC-10 & UC-11)', () {
    test('Initial state is clean', () {
      final bloc = DeliveryBloc(ordersService: mockService);
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.assignedOrders, isEmpty);
      expect(bloc.state.availableOrders, isEmpty);
      expect(bloc.state.error, isNull);
    });

    blocTest<DeliveryBloc, DeliveryState>(
      'LoadDeliveryHomeEvent emits loading and populates assigned and available orders',
      setUp: () {
        mockService.assignedOrders = [testOrder1];
        mockService.availableOrders = [testOrder2];
      },
      build: () => DeliveryBloc(ordersService: mockService),
      act: (bloc) => bloc.add(const LoadDeliveryHomeEvent('driver-1')),
      expect: () => [
        isA<DeliveryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DeliveryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.assignedOrders.length, 'assignedCount', 1)
            .having((s) => s.availableOrders.length, 'availableCount', 1),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'AcceptOrderEvent assigns order to driver and moves it to assigned list',
      setUp: () {
        mockService.availableOrders = [testOrder2];
        mockService.assignedOrders = [];
      },
      build: () => DeliveryBloc(ordersService: mockService),
      seed: () => DeliveryState(availableOrders: [testOrder2]),
      act: (bloc) => bloc.add(const AcceptOrderEvent(
        orderId: 'order-102',
        deliveryId: 'driver-1',
        deliveryName: 'John Driver',
      )),
      expect: () => [
        isA<DeliveryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DeliveryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isSuccess, 'isSuccess', true)
            .having((s) => s.assignedOrders.length, 'assignedOrders', 1)
            .having((s) => s.availableOrders.length, 'availableOrders', 0),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'RejectOrderEvent removes order from assigned list',
      setUp: () {
        mockService.assignedOrders = [testOrder1];
      },
      build: () => DeliveryBloc(ordersService: mockService),
      seed: () => DeliveryState(assignedOrders: [testOrder1]),
      act: (bloc) => bloc.add(const RejectOrderEvent(
        orderId: 'order-101',
        deliveryId: 'driver-1',
      )),
      expect: () => [
        isA<DeliveryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DeliveryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isSuccess, 'isSuccess', true)
            .having((s) => s.assignedOrders, 'assignedOrders', isEmpty),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'UpdateOrderStatusEvent with valid transition (accepted -> pickedUp) updates state successfully',
      setUp: () {
        mockService.assignedOrders = [testOrder1];
      },
      build: () => DeliveryBloc(ordersService: mockService),
      seed: () => DeliveryState(assignedOrders: [testOrder1]),
      act: (bloc) => bloc.add(const UpdateOrderStatusEvent(
        orderId: 'order-101',
        currentStatus: DeliveryStatus.accepted,
        targetStatus: DeliveryStatus.pickedUp,
      )),
      expect: () => [
        isA<DeliveryState>().having((s) => s.isLoading, 'isLoading', true),
        isA<DeliveryState>()
            .having((s) => s.isLoading, 'isLoading', false)
            .having((s) => s.isSuccess, 'isSuccess', true)
            .having((s) => s.assignedOrders.first.status, 'status', 'PICKED UP'),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'UpdateOrderStatusEvent with invalid transition (pending -> delivered) emits error and does not call service',
      build: () => DeliveryBloc(ordersService: mockService),
      act: (bloc) => bloc.add(const UpdateOrderStatusEvent(
        orderId: 'order-101',
        currentStatus: DeliveryStatus.pending,
        targetStatus: DeliveryStatus.delivered,
      )),
      expect: () => [
        isA<DeliveryState>().having(
          (s) => s.error,
          'error',
          contains('Invalid state transition'),
        ),
      ],
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'DismissNotificationEvent clears newOrderNotification',
      build: () => DeliveryBloc(ordersService: mockService),
      seed: () => DeliveryState(newOrderNotification: testOrder1),
      act: (bloc) => bloc.add(const DismissNotificationEvent()),
      expect: () => [
        isA<DeliveryState>().having((s) => s.newOrderNotification, 'notification', isNull),
      ],
    );
  });
}
