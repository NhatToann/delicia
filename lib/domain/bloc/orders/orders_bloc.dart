import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/address.dart';
import '../../models/order_filter.dart';
import '../../models/order_item.dart';
import '../../models/order_record.dart';
import '../../models/product_cart.dart';
import '../../services/app_failure.dart';
import '../../services/orders_service.dart';

part 'orders_event.dart';
part 'orders_state.dart';

/// OrdersBloc — owns the create-order flow used by CheckoutScreen (UC-04)
/// and the read-side feed used by [ClientOrdersScreen] (UC-05 preview).
///
/// Two surfaces live here:
///   * `lastOrder` — the single order created during the current
///     checkout. Kept around so the screen has *something* to show
///     during the first frame before the subscription catches up.
///   * `myOrders` + `filter` — every order belonging to the signed-in
///     client, sliced by the chip row. Backing it is a Firebase stream
///     keyed off [OrdersState.activeClientId]; the subscription is
///     opened on `OnLoadMyOrdersEvent(clientId)` and torn down on
///     logout or when the client id changes.
///
/// The stream listener cannot write to the state directly — by the time
/// a Firebase event arrives, the handler that opened the subscription
/// has already returned and its [Emitter] is closed. So the listener
/// feeds an internal `_OnMyOrdersUpdatedEvent` instead, which the bloc
/// handles like any other event.
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc({required OrdersService ordersService})
      : _ordersService = ordersService,
        super(const OrdersState()) {
    on<OnAddNewOrdersEvent>(_onAddNewOrders);
    on<OnUpdateLastOrderStatusEvent>(_onUpdateLastOrderStatus);
    on<OnClearLastOrderEvent>(_onClearLastOrder);
    on<OnLoadMyOrdersEvent>(_onLoadMyOrders);
    on<OnClearMyOrdersEvent>(_onClearMyOrders);
    on<OnChangeOrderFilterEvent>(_onChangeOrderFilter);
    on<OnCancelOrderEvent>(_onCancelOrder);
    on<_OnMyOrdersUpdatedEvent>(_onMyOrdersUpdated);
    on<_OnMyOrdersFailedEvent>(_onMyOrdersFailed);
  }

  final OrdersService _ordersService;
  StreamSubscription<List<OrderRecord>>? _myOrdersSub;

  Future<void> _onAddNewOrders(
    OnAddNewOrdersEvent event,
    Emitter<OrdersState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, lastOrder: null));
    try {
      final order = await _ordersService.addNewOrder(
        clientId: event.clientId,
        address: event.address,
        paymentMethod: event.paymentMethod,
        products: event.products,
        amount: event.amount,
      );
      emit(state.copyWith(isLoading: false, lastOrder: order));
      // After checkout the My-Orders stream might already contain this
      // order, but if it was created for a different clientId (admin
      // tooling, etc.) we still want the same screen to reflect the new
      // order. Optimistically prepend it so the user never sees a stale
      // view after a successful checkout.
      if (event.clientId == state.activeClientId) {
        final next = <OrderRecord>[order, ...state.myOrders];
        emit(state.copyWith(myOrders: next));
      }
    } on OrdersServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: asFailure(e)));
    }
  }

  void _onUpdateLastOrderStatus(
    OnUpdateLastOrderStatusEvent event,
    Emitter<OrdersState> emit,
  ) {
    final last = state.lastOrder;
    if (last == null) return;
    emit(state.copyWith(lastOrder: _replaceStatus(last, event.status)));
  }

  void _onClearLastOrder(
    OnClearLastOrderEvent event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(lastOrder: null, error: null));
  }

  /// Open (or rebind) the My Orders stream.
  ///
  /// Every call cancels the previous subscription, so the bloc can be
  /// pinged multiple times in a row — e.g. on sign-in, on pull-to-refresh,
  /// or after a `clientId` rotation — without leaking listeners.
  Future<void> _onLoadMyOrders(
    OnLoadMyOrdersEvent event,
    Emitter<OrdersState> emit,
  ) async {
    await _myOrdersSub?.cancel();
    _myOrdersSub = null;

    if (event.clientId.isEmpty) {
      emit(state.copyWith(
        clearActiveClientId: true,
        myOrders: const <OrderRecord>[],
        isLoadingMy: false,
        clearMyOrdersError: true,
      ));
      return;
    }

    emit(state.copyWith(
      activeClientId: event.clientId,
      isLoadingMy: state.myOrders.isEmpty,
      clearMyOrdersError: true,
    ));

    _myOrdersSub = _ordersService.watchMyOrders(event.clientId).listen(
      (orders) {
        if (isClosed) return;
        add(_OnMyOrdersUpdatedEvent(orders));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_OnMyOrdersFailedEvent(e));
      },
    );
  }

  void _onClearMyOrders(
    OnClearMyOrdersEvent event,
    Emitter<OrdersState> emit,
  ) async {
    await _myOrdersSub?.cancel();
    _myOrdersSub = null;
    emit(state.copyWith(
      clearActiveClientId: true,
      myOrders: const <OrderRecord>[],
      isLoadingMy: false,
      clearMyOrdersError: true,
    ));
  }

  void _onChangeOrderFilter(
    OnChangeOrderFilterEvent event,
    Emitter<OrdersState> emit,
  ) {
    if (event.filter == state.filter) return;
    emit(state.copyWith(filter: event.filter));
  }

  Future<void> _onCancelOrder(
    OnCancelOrderEvent event,
    Emitter<OrdersState> emit,
  ) async {
    // Optimistic update — flip the order's status locally first so the
    // UI moves to the Cancelled filter the moment the user taps. The
    // Firebase write happens after; on failure we re-emit the original
    // status and surface an error so the UI can revert.
    final before = state.myOrders;
    final optimistic = before
        .map((o) => o.id == event.orderId
            ? _replaceStatus(o, OrderRecord.statusCancelled)
            : o)
        .toList(growable: false);
    emit(state.copyWith(myOrders: optimistic));
    try {
      await _ordersService.cancelOrder(
        event.orderId,
        reason: event.reason,
      );
    } catch (e) {
      // Roll back: restore the previous list and bubble the error up.
      emit(state.copyWith(
        myOrders: before,
        myOrdersError: asFailure(e),
      ));
    }
  }

  /// A new batch arrived from the My Orders stream.
  void _onMyOrdersUpdated(
    _OnMyOrdersUpdatedEvent event,
    Emitter<OrdersState> emit,
  ) {
    // Keep `lastOrder` pointing at the most recent order so the
    // single-order card (used by the checkout flow) stays in sync with
    // the list.
    OrderRecord? nextLast = state.lastOrder;
    if (nextLast == null) {
      if (event.orders.isNotEmpty) nextLast = event.orders.first;
    } else {
      final lastId = nextLast.id;
      for (final o in event.orders) {
        if (o.id == lastId) {
          nextLast = o;
          break;
        }
      }
    }
    emit(state.copyWith(
      myOrders: event.orders,
      isLoadingMy: false,
      clearMyOrdersError: true,
      lastOrder: nextLast,
    ));
  }

  void _onMyOrdersFailed(
    _OnMyOrdersFailedEvent event,
    Emitter<OrdersState> emit,
  ) {
    emit(state.copyWith(
      isLoadingMy: false,
      myOrdersError: asFailure(event.error),
    ));
  }

  @override
  Future<void> close() async {
    await _myOrdersSub?.cancel();
    _myOrdersSub = null;
    return super.close();
  }

  OrderRecord _replaceStatus(OrderRecord order, String status) {
    // Build a new OrderRecord with the same fields except the status.
    return OrderRecord(
      id: order.id,
      clientId: order.clientId,
      addressId: order.addressId,
      street: order.street,
      reference: order.reference,
      latitude: order.latitude,
      longitude: order.longitude,
      paymentMethod: order.paymentMethod,
      amount: order.amount,
      status: status,
      products: List<OrderItem>.from(order.products),
      createdAt: order.createdAt,
    );
  }
}
