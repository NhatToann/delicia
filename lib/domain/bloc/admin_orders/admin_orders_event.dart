part of 'admin_orders_bloc.dart';

@immutable
abstract class AdminOrdersEvent {
  const AdminOrdersEvent();
}

/// Opens (or re-opens) the live order feed.
class AdminOrdersLoadRequested extends AdminOrdersEvent {
  const AdminOrdersLoadRequested();
}

/// Pull-to-refresh — re-opens the feed.
class AdminOrdersRefreshRequested extends AdminOrdersEvent {
  const AdminOrdersRefreshRequested();
}

/// Switches the visible status filter.
class AdminOrderFilterChanged extends AdminOrdersEvent {
  const AdminOrderFilterChanged(this.filter);
  final AdminOrderFilter filter;
}

/// Assigns a delivery driver to an order.
class AdminOrderAssignDeliveryRequested extends AdminOrdersEvent {
  const AdminOrderAssignDeliveryRequested({
    required this.orderId,
    required this.deliveryUserId,
    required this.deliveryUserName,
  });

  final String orderId;
  final String deliveryUserId;
  final String deliveryUserName;
}

/// Moves an order to another status.
class AdminOrderStatusUpdateRequested extends AdminOrdersEvent {
  const AdminOrderStatusUpdateRequested({
    required this.orderId,
    required this.status,
  });

  final String orderId;
  final String status;
}

/// Internal event — a new batch of orders arrived.
class _AdminOrdersUpdated extends AdminOrdersEvent {
  const _AdminOrdersUpdated(this.orders);
  final List<OrderRecord> orders;
}

/// Internal event — the order feed failed.
class _AdminOrdersFailed extends AdminOrdersEvent {
  const _AdminOrdersFailed(this.error);
  final Object error;
}
