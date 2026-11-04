import 'dart:async';

import 'package:bloc/bloc.dart';

import '../../models/delivery_status.dart';
import '../../models/order_record.dart';
import '../../services/orders_service.dart';
import 'driver_orders_event.dart';
import 'driver_orders_state.dart';

export 'driver_orders_event.dart';
export 'driver_orders_state.dart';

/// DriverOrdersBloc — owns Delivery Home list, accept/reject, live notification,
/// and the UC-11 delivery state machine transitions.
class DriverOrdersBloc extends Bloc<DriverOrdersEvent, DriverOrdersState> {
  DriverOrdersBloc({required OrdersService ordersService})
      : _ordersService = ordersService,
        super(const DriverOrdersState()) {
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

  String? _currentDeliveryId;
  final Set<String> _locallyRejectedOrderIds = {};

  List<OrderRecord> _cachedAssigned = [];
  List<OrderRecord> _cachedAvailable = [];

  bool _hasActiveDelivery(List<OrderRecord> assigned) => assigned.any((o) =>
      o.status != OrderRecord.statusDelivered &&
      o.status != OrderRecord.statusCancelled);

  Future<void> _onLoadDeliveryHome(
    LoadDeliveryHomeEvent event,
    Emitter<DriverOrdersState> emit,
  ) async {
    _currentDeliveryId = event.deliveryId;
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final results = await Future.wait([
        _ordersService.getOrdersForDelivery(event.deliveryId),
        _ordersService.getAvailableOrders(),
      ]);
      _cachedAssigned = results[0];
      _cachedAvailable = results[1].where((o) {
        if (_locallyRejectedOrderIds.contains(o.id)) return false;
        if (o.rejectedBy.contains(event.deliveryId)) return false;
        return true;
      }).toList();

      final hasActive = _hasActiveDelivery(_cachedAssigned);

      emit(state.copyWith(
        isLoading: false,
        assignedOrders: _cachedAssigned,
        availableOrders: hasActive ? const [] : _cachedAvailable,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onWatchDeliveryHome(
    WatchDeliveryHomeEvent event,
    Emitter<DriverOrdersState> emit,
  ) async {
    _currentDeliveryId = event.deliveryId;
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
      final filtered = available.where((o) {
        if (_locallyRejectedOrderIds.contains(o.id)) return false;
        if (o.rejectedBy.contains(event.deliveryId)) return false;
        return true;
      }).toList();
      _cachedAvailable = filtered;
      add(DeliveryOrdersUpdatedEvent(
        assignedOrders: _cachedAssigned,
        availableOrders: _cachedAvailable,
      ));
    });
  }

  void _onDeliveryOrdersUpdated(
    DeliveryOrdersUpdatedEvent event,
    Emitter<DriverOrdersState> emit,
  ) {
    final filteredAvailable = event.availableOrders.where((order) {
      if (_locallyRejectedOrderIds.contains(order.id)) return false;
      if (_currentDeliveryId != null &&
          order.rejectedBy.contains(_currentDeliveryId)) {
        return false;
      }
      return true;
    }).toList();

    final hasActive = _hasActiveDelivery(event.assignedOrders);
    final visibleAvailable = hasActive ? const <OrderRecord>[] : filteredAvailable;

    OrderRecord? newlyAssigned;
    if (!hasActive) {
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
          for (final order in filteredAvailable) {
            if (!existingAvailableIds.contains(order.id)) {
              newlyAssigned = order;
              break;
            }
          }
        }
      }
    }

    emit(state.copyWith(
      isLoading: false,
      assignedOrders: event.assignedOrders,
      availableOrders: visibleAvailable,
      newOrderNotification: newlyAssigned ?? (hasActive ? null : state.newOrderNotification),
    ));
  }

  Future<void> _onAcceptOrder(
    AcceptOrderEvent event,
    Emitter<DriverOrdersState> emit,
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
        successMessage: 'Nhận đơn hàng thành công!',
        assignedOrders: newAssigned,
        availableOrders: const [],
        activeOrder: updatedOrder,
        clearNotification: true,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onRejectOrder(
    RejectOrderEvent event,
    Emitter<DriverOrdersState> emit,
  ) async {
    _locallyRejectedOrderIds.add(event.orderId);
    emit(state.copyWith(isLoading: true, clearError: true, clearSuccess: true));
    try {
      await _ordersService.rejectOrder(event.orderId, event.deliveryId);

      final currentAssigned =
          _cachedAssigned.isNotEmpty ? _cachedAssigned : state.assignedOrders;
      final currentAvailable =
          _cachedAvailable.isNotEmpty ? _cachedAvailable : state.availableOrders;
      final newAssigned =
          currentAssigned.where((o) => o.id != event.orderId).toList();
      final newAvailable =
          currentAvailable.where((o) => o.id != event.orderId).toList();
      _cachedAssigned = newAssigned;
      _cachedAvailable = newAvailable;

      final hasActive = _hasActiveDelivery(newAssigned);
      final visibleAvailable = hasActive ? const <OrderRecord>[] : newAvailable;

      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: 'Đã từ chối đơn hàng.',
        assignedOrders: newAssigned,
        availableOrders: visibleAvailable,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<void> _onUpdateOrderStatus(
    UpdateOrderStatusEvent event,
    Emitter<DriverOrdersState> emit,
  ) async {
    // 1. State machine transition validation
    if (!event.currentStatus.canTransitionTo(event.targetStatus)) {
      final msg =
          'Không thể chuyển trạng thái từ ${event.currentStatus.labelVi} sang ${event.targetStatus.labelVi}.';
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
      _cachedAssigned = updatedAssigned;

      OrderRecord? updatedActive = state.activeOrder;
      if (updatedActive != null && updatedActive.id == event.orderId) {
        updatedActive = updatedActive.copyWith(
          status: event.targetStatus.dbStatus,
          deliveryPhoto: event.deliveryPhoto ?? updatedActive.deliveryPhoto,
        );
      }

      final hasActive = _hasActiveDelivery(updatedAssigned);
      final visibleAvailable = hasActive
          ? const <OrderRecord>[]
          : _cachedAvailable.where((o) {
              if (_locallyRejectedOrderIds.contains(o.id)) return false;
              if (_currentDeliveryId != null &&
                  o.rejectedBy.contains(_currentDeliveryId)) {
                return false;
              }
              return true;
            }).toList();

      final successMsg = event.targetStatus == DeliveryStatus.delivered
          ? 'Đã hoàn thành giao đơn hàng thành công!'
          : 'Cập nhật trạng thái: ${event.targetStatus.labelVi}!';

      emit(state.copyWith(
        isLoading: false,
        isSuccess: true,
        successMessage: successMsg,
        assignedOrders: updatedAssigned,
        availableOrders: visibleAvailable,
        activeOrder: updatedActive,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  void _onDismissNotification(
    DismissNotificationEvent event,
    Emitter<DriverOrdersState> emit,
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
