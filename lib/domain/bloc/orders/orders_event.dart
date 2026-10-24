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

/// UC-05 — makes an existing order the one the live-tracking map follows.
///
/// The checkout flow publishes its order through [OnAddNewOrdersEvent], but
/// a client that opens the map from the *order history* has no such order in
/// the bloc yet.  This event hands the already-loaded [OrderRecord] over so
/// the map can centre on it.
class OnTrackOrderEvent extends OrdersEvent {
  final OrderRecord order;

  const OnTrackOrderEvent(this.order);
}