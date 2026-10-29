part of 'orders_bloc.dart';

@immutable
abstract class OrdersEvent {
  const OrdersEvent();
}

class OnAddNewOrdersEvent extends OrdersEvent {
  final String clientId;
  final Address address;
  final String paymentMethod;
  final List<ProductCart> products;
  final double amount;

  const OnAddNewOrdersEvent({
    required this.clientId,
    required this.address,
    required this.paymentMethod,
    required this.products,
    required this.amount,
  });
}

class OnUpdateLastOrderStatusEvent extends OrdersEvent {
  final String status;
  const OnUpdateLastOrderStatusEvent(this.status);
}

class OnClearLastOrderEvent extends OrdersEvent {
  const OnClearLastOrderEvent();
}

/// Bind (or rebind) the My Orders stream to a client id.
///
/// Fires on:
///   - Sign-in (the home screen picks it up the moment Auth lands),
///   - "Reload" pull-to-refresh on the My Orders screen,
///   - Returning from checkout (so the freshly-created order shows up).
class OnLoadMyOrdersEvent extends OrdersEvent {
  const OnLoadMyOrdersEvent(this.clientId);
  final String clientId;
}

/// Tear down the My Orders stream and wipe the cached list. Used on
/// logout so the next user doesn't briefly see the previous user's
/// orders.
class OnClearMyOrdersEvent extends OrdersEvent {
  const OnClearMyOrdersEvent();
}

/// Switch the visible filter (active / completed / cancelled). Pure
/// UI state — does not touch the network.
class OnChangeOrderFilterEvent extends OrdersEvent {
  const OnChangeOrderFilterEvent(this.filter);
  final OrderFilter filter;
}

/// Cancellation flow lands in a later use-case. For now the bloc just
/// marks the order CANCELLED so the UI can react, and the Firebase
/// write goes through [OrdersService.cancelOrder].
class OnCancelOrderEvent extends OrdersEvent {
  const OnCancelOrderEvent({required this.orderId, this.reason});
  final String orderId;
  final String? reason;
}

/// Internal event — a batch arrived from the My Orders stream.
///
/// The subscription outlives the handler that opened it, so the data
/// can't be pushed through that handler's [Emitter] (it would already be
/// closed by then). Instead the listener feeds an internal event, which
/// the bloc handles like any other.
class _OnMyOrdersUpdatedEvent extends OrdersEvent {
  const _OnMyOrdersUpdatedEvent(this.orders);
  final List<OrderRecord> orders;
}

/// Internal event — the My Orders stream failed.
class _OnMyOrdersFailedEvent extends OrdersEvent {
  const _OnMyOrdersFailedEvent(this.error);
  final Object error;
}
