part of 'admin_orders_bloc.dart';

@immutable
class AdminOrdersState {
  /// True while the first batch of orders is loading.
  final bool isLoading;

  /// True while an assign / status write is running.
  final bool isSubmitting;

  /// The last failure, if any.
  final AppFailure? error;

  /// Every order, newest first.
  final List<OrderRecord> orders;

  /// The orders matching the current [filter].
  final List<OrderRecord> visibleOrders;

  /// The status filter the list is showing.
  final AdminOrderFilter filter;

  /// `true` after a successful write.
  final bool actionSucceeded;

  const AdminOrdersState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.orders = const <OrderRecord>[],
    this.visibleOrders = const <OrderRecord>[],
    this.filter = AdminOrderFilter.all,
    this.actionSucceeded = false,
  });

  AdminOrdersState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    AppFailure? error,
    bool clearError = false,
    List<OrderRecord>? orders,
    List<OrderRecord>? visibleOrders,
    AdminOrderFilter? filter,
    bool? actionSucceeded,
    bool clearActionSucceeded = false,
  }) {
    return AdminOrdersState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      orders: orders ?? this.orders,
      visibleOrders: visibleOrders ?? this.visibleOrders,
      filter: filter ?? this.filter,
      actionSucceeded: clearActionSucceeded
          ? false
          : (actionSucceeded ?? this.actionSucceeded),
    );
  }
}
