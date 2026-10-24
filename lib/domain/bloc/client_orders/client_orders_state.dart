part of 'client_orders_bloc.dart';

@immutable
class ClientOrdersState {
  final bool isLoading;
  final String? error;

  /// Full order list as known to this BLoC (sorted newest-first).
  final List<OrderRecord> orders;

  /// The order that was most recently mutated (cancellation, status
  /// refresh).  Consumers like the order-detail screen may read this to
  /// show inline success toasts without re-fetching everything.
  final OrderRecord? lastUpdatedOrder;

  /// Client whose orders are currently represented in [orders].  Used so a
  /// logged-out / switched-account user doesn't accidentally cancel
  /// somebody else's order.
  final String? activeClientId;

  /// Whether the realtime listener is currently attached.  UI uses this
  /// to show a "live" indicator.
  final bool realtimeActive;

  /// Set while a cancellation is in flight so the UI can show a spinner
  /// on the matching card.
  final String? cancellingOrderId;

  const ClientOrdersState({
    this.isLoading = false,
    this.error,
    this.orders = const [],
    this.lastUpdatedOrder,
    this.activeClientId,
    this.realtimeActive = false,
    this.cancellingOrderId,
  });

  /// Active orders — anything not yet delivered / cancelled.
  ///
  /// Terminal states ([ClientOrderStatuses.delivered] /
  /// [ClientOrderStatuses.cancelled]) are excluded explicitly.  Relying on
  /// the timeline list alone is wrong because `CANCELLED` is not part of
  /// the delivery timeline and would otherwise leak into this tab.
  List<OrderRecord> get activeOrders => orders
      .where(
        (o) => !ClientOrderStatuses.isTerminal(o.status),
      )
      .toList();

  /// History — delivered + cancelled.
  List<OrderRecord> get historyOrders => orders
      .where((o) => ClientOrderStatuses.isTerminal(o.status))
      .toList();

  ClientOrdersState copyWith({
    bool? isLoading,
    String? error,
    List<OrderRecord>? orders,
    OrderRecord? lastUpdatedOrder,
    bool clearLastUpdatedOrder = false,
    String? activeClientId,
    bool? realtimeActive,
    String? cancellingOrderId,
    bool clearCancellingOrderId = false,
    bool clearError = false,
  }) {
    return ClientOrdersState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      orders: orders ?? this.orders,
      lastUpdatedOrder: clearLastUpdatedOrder
          ? null
          : (lastUpdatedOrder ?? this.lastUpdatedOrder),
      activeClientId: activeClientId ?? this.activeClientId,
      realtimeActive: realtimeActive ?? this.realtimeActive,
      cancellingOrderId: clearCancellingOrderId
          ? null
          : (cancellingOrderId ?? this.cancellingOrderId),
    );
  }
}
