part of 'orders_bloc.dart';

@immutable
class OrdersState {
  final bool isLoading;
  final String? error;
  final OrderRecord? lastOrder;

  const OrdersState({
    this.isLoading = false,
    this.error,
    this.lastOrder,
  });

  OrdersState copyWith({
    bool? isLoading,
    String? error,
    OrderRecord? lastOrder,
    bool clearError = false,
    bool clearLastOrder = false,
  }) {
    return OrdersState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastOrder: clearLastOrder ? null : (lastOrder ?? this.lastOrder),
    );
  }
}