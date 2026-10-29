import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../models/delivery_status.dart';
import '../../models/order_record.dart';
import '../../services/orders_service.dart';
import 'delivery_event.dart';
import 'delivery_state.dart';

export 'delivery_event.dart';
export 'delivery_state.dart';

/// DeliveryBloc — owns Delivery Home list, accept/reject, live notification,
/// and the UC-11 delivery state machine transitions.
class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  DeliveryBloc({required OrdersService ordersService})
      : _ordersService = ordersService,
        super(const DeliveryState()) {
    on<LoadDeliveryHomeEvent>(_onLoadDeliveryHome);
    on<WatchDeliveryHomeEvent>(_onWatchDeliveryHome);
    on<DeliveryOrdersUpdatedEvent>(_onDeliveryOrdersUpdated);
    on<AcceptOrderEvent>(_onAcceptOrder);
    on<RejectOrderEvent>(_onRejectOrder);
    on<UpdateOrderStatusEvent>(_onUpdateOrderStatus);
    on<DismissNotificationEvent>(_onDismissNotification);
  }

  final OrdersService _ordersService;
  StreamSubscription<List<OrderRecord>>? _assignedSub;
  StreamSubscription<List<OrderRecord>>? _availableSub;

  List<OrderRecord> _cachedAssigned = [];
  List<OrderRecord> _cachedAvailable = [];

  Future<void> _onLoadDeliveryHome(
    LoadDeliveryHomeEvent event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _ordersService.getOrdersForDelivery(event.deliveryId),
        _ordersService.getAvailableOrders(),
      ]);
      _cachedAssigned = results[0];
      _cachedAvailable = results[1];

      emit(state.copyWith(
        isLoading: false,
        assignedOrders: _cachedAssigned,
        availableOrders: _cachedAvailable,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onWatchDeliveryHome(
    WatchDeliveryHomeEvent event,
    Emitter<DeliveryState> emit,
  ) async {
    await _assignedSub?.cancel();
    await _availableSub?.cancel();

    _assignedSub =
        _ordersService.watchDeliveryOrders(event.deliveryId).listen((assigned) {
      _cachedAssigned = assigned;
      add(DeliveryOrdersUpdatedEvent(
        assignedOrders: _cachedAssigned,
        availableOrders: _cachedAvailable,
      ));
    });

    _availableSub = _ordersService.watchAvailableOrders().listen((available) {
      _cachedAvailable = available;
      add(DeliveryOrdersUpdatedEvent(
        assignedOrders: _cachedAssigned,
        availableOrders: _cachedAvailable,
      ));
    });
  }

  void _onDeliveryOrdersUpdated(
    DeliveryOrdersUpdatedEvent event,
    Emitter<DeliveryState> emit,
  ) {
    OrderRecord? newlyAssigned;
    final hadPriorState =
        state.assignedOrders.isNotEmpty || state.availableOrders.isNotEmpty;

    if (hadPriorState) {
      final existingAssignedIds = state.assignedOrders.map((o) => o.id).toSet();
      for (final order in event.assignedOrders) {
        if (!existingAssignedIds.contains(order.id)) {
          newlyAssigned = order;
          break;
        }
      }

      if (newlyAssigned == null) {
        final existingAvailableIds =
            state.availableOrders.map((o) => o.id).toSet();
        for (final order in event.availableOrders) {
          if (!existingAvailableIds.contains(order.id)) {
            newlyAssigned = order;
            break;
          }
        }
      }
    }

    emit(state.copyWith(
      isLoading: false,
      assignedOrders: event.assignedOrders,
      availableOrders: event.availableOrders,
      newOrderNotification: newlyAssigned ?? state.newOrderNotification,
    ));
  }

  Future<void> _onAcceptOrder(
    AcceptOrderEvent event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      await _ordersService.acceptOrder(
        event.orderId,
        event.deliveryId,
        deliveryName: event.deliveryName,
      );

      final currentAvailable =
          _cachedAvailable.isNotEmpty ? _cachedAvailable : state.availableOrders;
      final currentAssigned =
          _cachedAssigned.isNotEmpty ? _cachedAssigned : state.assignedOrders;

      final matched = currentAvailable.where((o) => o.id == event.orderId);
      final OrderRecord acceptedOrder;
      if (matched.isNotEmpty) {
        acceptedOrder = matched.first;
      } else {
        final assignedMatched =
            currentAssigned.where((o) => o.id == event.orderId);
        if (assignedMatched.isNotEmpty) {
          acceptedOrder = assignedMatched.first;
        } else {
          acceptedOrder = OrderRecord(
            id: event.orderId,
            clientId: '',
            addressId: '',
            street: '',
            reference: '',
            latitude: 0.0,
            longitude: 0.0,
            paymentMethod: 'CASH',
            amount: 0.0,
            products: const [],
            status: DeliveryStatus.accepted.dbStatus,
            createdAt: DateTime.now(),
          );
        }
      }

      final updatedOrder = acceptedOrder.copyWith(
        deliveryId: event.deliveryId,
        deliveryName: event.deliveryName,
        status: DeliveryStatus.accepted.dbStatus,
      );

      final newAvailable =
          currentAvailable.where((o) => o.id != event.orderId).toList();
      final newAssigned = [
        updatedOrder,
        ...currentAssigned.where((o) => o.id != event.orderId)
      ];
      _cachedAvailable = newAvailable;
      _cachedAssigned = newAssigned;

      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Order accepted successfully!',
        assignedOrders: newAssigned,
        availableOrders: newAvailable,
        activeOrder: updatedOrder,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onRejectOrder(
    RejectOrderEvent event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      await _ordersService.rejectOrder(event.orderId, event.deliveryId);

      final currentAssigned =
          _cachedAssigned.isNotEmpty ? _cachedAssigned : state.assignedOrders;
      final currentAvailable =
          _cachedAvailable.isNotEmpty ? _cachedAvailable : state.availableOrders;
      final newAssigned =
          currentAssigned.where((o) => o.id != event.orderId).toList();
      _cachedAssigned = newAssigned;
      _cachedAvailable = currentAvailable;

      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Order rejected.',
        assignedOrders: newAssigned,
        availableOrders: currentAvailable,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatusEvent event,
    Emitter<DeliveryState> emit,
  ) async {
    // 1. State machine transition validation
    if (!event.currentStatus.canTransitionTo(event.targetStatus)) {
      final msg =
          'Invalid state transition: Cannot transition from ${event.currentStatus.label} to ${event.targetStatus.label}.';
      emit(state.copyWith(error: msg));
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      await _ordersService.updateDeliveryStatus(
        event.orderId,
        event.targetStatus.dbStatus,
        deliveryPhoto: event.deliveryPhoto,
      );

      final updatedAssigned = state.assignedOrders.map((o) {
        if (o.id == event.orderId) {
          return o.copyWith(
            status: event.targetStatus.dbStatus,
            deliveryPhoto: event.deliveryPhoto ?? o.deliveryPhoto,
          );
        }
        return o;
      }).toList();

      OrderRecord? updatedActive = state.activeOrder;
      if (updatedActive != null && updatedActive.id == event.orderId) {
        updatedActive = updatedActive.copyWith(
          status: event.targetStatus.dbStatus,
          deliveryPhoto: event.deliveryPhoto ?? updatedActive.deliveryPhoto,
        );
      }

      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Order status updated to ${event.targetStatus.label}!',
        assignedOrders: updatedAssigned,
        activeOrder: updatedActive,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onDismissNotification(
    DismissNotificationEvent event,
    Emitter<DeliveryState> emit,
  ) {
    emit(state.copyWith(clearNotification: true));
  }

  @override
  Future<void> close() {
    _assignedSub?.cancel();
    _availableSub?.cancel();
    return super.close();
  }
}
