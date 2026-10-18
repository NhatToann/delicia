import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/address.dart';
import '../../models/order_item.dart';
import '../../models/order_record.dart';
import '../../models/product_cart.dart';
import '../../services/orders_service.dart';

part 'orders_event.dart';
part 'orders_state.dart';

/// OrdersBloc — owns the create-order flow used by CheckoutScreen (UC-04).
///
/// Other read-side order events (`OnUpdateStatusOrderToDispatchedEvent` etc.)
/// are owned by Member A (read/cancel) and Member B (admin view) — only the
/// `OnAddNewOrdersEvent` event lives here so the Leader does not collide
/// with their files.
class OrdersBloc extends Bloc<OrdersEvent, OrdersState> {
  OrdersBloc({required OrdersService ordersService})
      : _ordersService = ordersService,
        super(const OrdersState()) {
    on<OnAddNewOrdersEvent>(_onAddNewOrders);
    on<OnUpdateLastOrderStatusEvent>(_onUpdateLastOrderStatus);
    on<OnClearLastOrderEvent>(_onClearLastOrder);
  }

  final OrdersService _ordersService;

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
    } on OrdersServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
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