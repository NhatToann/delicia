import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/admin_order_filter.dart';
import '../../models/order_record.dart';
import '../../services/admin_orders_service.dart';
import '../../services/app_failure.dart';

part 'admin_orders_event.dart';
part 'admin_orders_state.dart';

/// AdminOrdersBloc — the admin's view of every order (UC-09).
///
/// The bloc watches the whole `delicia/orders` node, so the list updates
/// in realtime as customers order, couriers move and the kitchen moves
/// an order along the pipeline.
///
/// As everywhere else in this project, the Firebase listener never
/// writes to the state directly — it feeds an internal event instead,
/// because the handler that opened the subscription has already
/// returned by the time the data arrives.
class AdminOrdersBloc extends Bloc<AdminOrdersEvent, AdminOrdersState> {
  AdminOrdersBloc({required AdminOrdersService ordersService})
      : _ordersService = ordersService,
        super(const AdminOrdersState()) {
    on<AdminOrdersLoadRequested>(_onLoadRequested);
    on<AdminOrdersRefreshRequested>(_onRefreshRequested);
    on<AdminOrderFilterChanged>(_onFilterChanged);
    on<AdminOrderAssignDeliveryRequested>(_onAssignDelivery);
    on<AdminOrderStatusUpdateRequested>(_onStatusUpdate);
    on<_AdminOrdersUpdated>(_onOrdersUpdated);
    on<_AdminOrdersFailed>(_onOrdersFailed);
  }

  final AdminOrdersService _ordersService;

  StreamSubscription<List<OrderRecord>>? _ordersSub;

  Future<void> _onLoadRequested(
    AdminOrdersLoadRequested event,
    Emitter<AdminOrdersState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    await _ordersSub?.cancel();
    _ordersSub = null;

    _ordersSub = _ordersService.watchAllOrders().listen(
      (orders) {
        if (isClosed) return;
        add(_AdminOrdersUpdated(orders));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_AdminOrdersFailed(e));
      },
    );
  }

  Future<void> _onRefreshRequested(
    AdminOrdersRefreshRequested event,
    Emitter<AdminOrdersState> emit,
  ) async {
    await _onLoadRequested(const AdminOrdersLoadRequested(), emit);
  }

  void _onFilterChanged(
    AdminOrderFilterChanged event,
    Emitter<AdminOrdersState> emit,
  ) {
    if (event.filter == state.filter) return;
    emit(
      state.copyWith(
        filter: event.filter,
        visibleOrders: _filter(state.orders, event.filter),
      ),
    );
  }

  Future<void> _onAssignDelivery(
    AdminOrderAssignDeliveryRequested event,
    Emitter<AdminOrdersState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _ordersService.assignDelivery(
        orderId: event.orderId,
        deliveryUserId: event.deliveryUserId,
        deliveryUserName: event.deliveryUserName,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  Future<void> _onStatusUpdate(
    AdminOrderStatusUpdateRequested event,
    Emitter<AdminOrdersState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _ordersService.updateOrderStatus(
        orderId: event.orderId,
        status: event.status,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  void _onOrdersUpdated(
    _AdminOrdersUpdated event,
    Emitter<AdminOrdersState> emit,
  ) {
    emit(
      state.copyWith(
        isLoading: false,
        clearError: true,
        orders: event.orders,
        visibleOrders: _filter(event.orders, state.filter),
      ),
    );
  }

  void _onOrdersFailed(
    _AdminOrdersFailed event,
    Emitter<AdminOrdersState> emit,
  ) {
    emit(state.copyWith(isLoading: false, error: asFailure(event.error)));
  }

  static List<OrderRecord> _filter(
    List<OrderRecord> source,
    AdminOrderFilter filter,
  ) =>
      source.where(filter.accepts).toList(growable: false);

  @override
  Future<void> close() async {
    await _ordersSub?.cancel();
    _ordersSub = null;
    return super.close();
  }
}
