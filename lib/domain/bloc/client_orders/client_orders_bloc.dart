import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/order_record.dart';
import '../../services/client_orders_service.dart';

part 'client_orders_event.dart';
part 'client_orders_state.dart';

/// ClientOrdersBloc — powers the client's Order list (Active + History)
/// and Order detail screens (UC-05).
///
/// Responsibilities:
///   - load / stream the authenticated client's orders
///   - real-time updates when the delivery / admin side progresses them
///   - cancel an order, enforcing the state's cancellation policy
///
/// Cancellation rule:
///   The status must be in [ClientOrderStatuses.cancellableStatuses]
///   (currently only `PAID OUT`).  Any later status returns a typed
///   service error and the BLoC surfaces it as a user-friendly message.
///
/// The shared write-side `OrdersBloc` (UC-04) stays untouched — this BLoC
/// talks to its own [ClientOrdersService] contract so the Leader's
/// interface (and every fake implementing it) is never modified.
class ClientOrdersBloc extends Bloc<ClientOrdersEvent, ClientOrdersState> {
  ClientOrdersBloc({required this._ordersService})
    : super(const ClientOrdersState()) {
    on<OnLoadClientOrdersEvent>(_onLoad);
    on<OnSubscribeClientOrdersEvent>(_onSubscribe);
    on<OnCancelOrderEvent>(_onCancel);
    on<OnClearClientOrdersErrorEvent>(
      (_, emit) => emit(state.copyWith(clearError: true)),
    );
    on<OnRefreshClientOrdersEvent>(_onRefresh);
  }

  final ClientOrdersService _ordersService;

  /// Used by the order-list screen so realtime edits flow into the list.
  StreamSubscription<List<OrderRecord>>? _listSubscription;

  Future<void> _onLoad(
    OnLoadClientOrdersEvent event,
    Emitter<ClientOrdersState> emit,
  ) async {
    if (event.clientId.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Sign in to view your orders.',
          orders: const [],
          lastUpdatedOrder: null,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final orders = await _ordersService.listOrdersByClient(event.clientId);
      emit(
        state.copyWith(
          isLoading: false,
          orders: orders,
          activeClientId: event.clientId,
        ),
      );
    } on ClientOrdersServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not load orders: $e'),
      );
    }
  }

  Future<void> _onSubscribe(
    OnSubscribeClientOrdersEvent event,
    Emitter<ClientOrdersState> emit,
  ) async {
    if (event.clientId.isEmpty) return;
    // Guard against duplicate live subscriptions — the order-list screen
    // re-subscribes whenever the user logs in / out, so guard explicitly.
    await _listSubscription?.cancel();
    try {
      _listSubscription = _ordersService
          .watchClientOrders(event.clientId)
          .listen(
            (orders) {
              add(OnLoadClientOrdersEvent(clientId: event.clientId));
            },
            onError: (Object e) {
              add(OnLoadClientOrdersEvent(clientId: event.clientId));
            },
            cancelOnError: false,
          );
      emit(
        state.copyWith(
          activeClientId: event.clientId,
          realtimeActive: true,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          realtimeActive: false,
          error: 'Realtime listener unavailable: $e',
        ),
      );
    }
  }

  Future<void> _onRefresh(
    OnRefreshClientOrdersEvent event,
    Emitter<ClientOrdersState> emit,
  ) async {
    final cid = event.clientId.isEmpty
        ? (state.activeClientId ?? '')
        : event.clientId;
    if (cid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to refresh your orders.'));
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final orders = await _ordersService.listOrdersByClient(cid);
      emit(
        state.copyWith(
          isLoading: false,
          orders: orders,
          activeClientId: cid,
        ),
      );
    } on ClientOrdersServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Refresh failed: $e'));
    }
  }

  Future<void> _onCancel(
    OnCancelOrderEvent event,
    Emitter<ClientOrdersState> emit,
  ) async {
    final cid = event.clientId.isEmpty
        ? (state.activeClientId ?? '')
        : event.clientId;
    if (cid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to cancel an order.'));
      return;
    }
    // Resolve the live status before allowing the cancellation.  Prefer the
    // locally cached record; fall back to a direct read so the rule holds
    // even when the list hasn't been loaded yet (deep-link / cold start).
    final cached = _findOrder(state.orders, event.orderId);
    final current = cached ?? await _safeGetOrder(event.orderId);
    if (current == null) {
      emit(state.copyWith(error: 'Order not found. Refresh and try again.'));
      return;
    }
    if (!ClientOrderStatuses.cancellableStatuses.contains(current.status)) {
      emit(
        state.copyWith(
          error:
              'This order can no longer be cancelled (status: ${current.status}).',
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        cancellingOrderId: event.orderId,
        clearError: true,
        lastUpdatedOrder: null,
      ),
    );
    try {
      final updated = await _ordersService.cancelOrder(
        orderId: event.orderId,
        reason: event.reason,
      );
      final nextOrders = List<OrderRecord>.from(state.orders)
        ..removeWhere((o) => o.id == event.orderId)
        ..insert(0, updated);
      emit(
        state.copyWith(
          clearCancellingOrderId: true,
          orders: nextOrders,
          lastUpdatedOrder: updated,
          activeClientId: cid,
        ),
      );
      // Refresh from the source so any side-effects (status broadcast)
      // become visible.
      add(OnRefreshClientOrdersEvent(clientId: cid));
    } on ClientOrdersServiceException catch (e) {
      emit(
        state.copyWith(
          clearCancellingOrderId: true,
          error: e.message,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          clearCancellingOrderId: true,
          error: 'Cancellation failed: $e',
        ),
      );
    }
  }

  OrderRecord? _findOrder(List<OrderRecord> orders, String id) {
    for (final o in orders) {
      if (o.id == id) return o;
    }
    return null;
  }

  /// Reads a single order without letting a failure bubble up — used by
  /// the cancellation guard, where a network error must surface as the
  /// service's own rejection rather than a crash.
  Future<OrderRecord?> _safeGetOrder(String orderId) async {
    try {
      final stream = _ordersService.watchOrderUpdates(orderId);
      return await stream.first;
    } on ClientOrdersServiceException {
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() async {
    await _listSubscription?.cancel();
    return super.close();
  }
}
