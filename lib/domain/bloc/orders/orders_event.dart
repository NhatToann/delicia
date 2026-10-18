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