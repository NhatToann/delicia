part of 'orders_bloc.dart';

@immutable
class OrdersState {
  /// True only while the checkout create-order flow is running.
  final bool isLoading;

  /// Error from the create-order flow. The My-Orders subscription uses
  /// [myOrdersError] so the two never bleed into each other.
  final AppFailure? error;

  /// Snapshot of the order created in the current checkout (if any).
  /// Used by [ClientOrdersScreen] when only one order has been placed
  /// during this session; the moment the My-Orders stream delivers its
  /// first batch, [lastOrder] is replaced by it (members see both).
  final OrderRecord? lastOrder;

  /// Client id currently bound to the My-Orders stream. Tracked so the
  /// bloc can detect logins / logouts and refresh accordingly.
  final String? activeClientId;

  /// All orders (across every filter) for [activeClientId], newest first.
  /// The My Orders screen slices this by [filter] for the visible list.
  final List<OrderRecord> myOrders;

  /// True while the very first batch of my-orders is loading. Subsequent
  /// updates keep the previous list visible so the stream doesn't
  /// flicker on every Firebase write.
  final bool isLoadingMy;

  /// Latest error from the My-Orders stream. Distinct from [error].
  final AppFailure? myOrdersError;

  /// Which subset of [myOrders] the UI is currently showing.
  final OrderFilter filter;

  const OrdersState({
    this.isLoading = false,
    this.error,
    this.lastOrder,
    this.activeClientId,
    this.myOrders = const <OrderRecord>[],
    this.isLoadingMy = false,
    this.myOrdersError,
    this.filter = OrderFilter.active,
  });

  OrdersState copyWith({
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
    OrderRecord? lastOrder,
    bool clearLastOrder = false,
    String? activeClientId,
    bool clearActiveClientId = false,
    List<OrderRecord>? myOrders,
    bool? isLoadingMy,
    AppFailure? myOrdersError,
    bool clearMyOrdersError = false,
    OrderFilter? filter,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastOrder: clearLastOrder ? null : (lastOrder ?? this.lastOrder),
      activeClientId:
          clearActiveClientId ? null : (activeClientId ?? this.activeClientId),
      myOrders: myOrders ?? this.myOrders,
      isLoadingMy: isLoadingMy ?? this.isLoadingMy,
      myOrdersError:
          clearMyOrdersError ? null : (myOrdersError ?? this.myOrdersError),
      filter: filter ?? this.filter,
    );
  }

  /// [myOrders] filtered by [filter]. Built on the fly — the list is at
  /// most a few dozen items per user.
  List<OrderRecord> get filteredMyOrders =>
      myOrders.where(filter.accepts).toList(growable: false);
}
