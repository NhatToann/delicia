import 'package:flutter/foundation.dart';
import '../../models/order_record.dart';

@immutable
class DeliveryState {
  final bool isLoading;
  final bool isSuccess;
  final String? successMessage;
  final String? error;
  final List<OrderRecord> assignedOrders;
  final List<OrderRecord> availableOrders;
  final OrderRecord? activeOrder;
  final OrderRecord? newOrderNotification;

  const DeliveryState({
    this.isLoading = false,
    this.isSuccess = false,
    this.successMessage,
    this.error,
    this.assignedOrders = const [],
    this.availableOrders = const [],
    this.activeOrder,
    this.newOrderNotification,
  });

  DeliveryState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? successMessage,
    String? error,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearNotification = false,
    List<OrderRecord>? assignedOrders,
    List<OrderRecord>? availableOrders,
    OrderRecord? activeOrder,
    OrderRecord? newOrderNotification,
  }) {
    return DeliveryState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: clearSuccess ? false : (isSuccess ?? this.isSuccess),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      error: clearError ? null : (error ?? this.error),
      assignedOrders: assignedOrders ?? this.assignedOrders,
      availableOrders: availableOrders ?? this.availableOrders,
      activeOrder: activeOrder ?? this.activeOrder,
      newOrderNotification: clearNotification
          ? null
          : (newOrderNotification ?? this.newOrderNotification),
    );
  }
}
