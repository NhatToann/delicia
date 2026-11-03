import 'package:flutter/foundation.dart';
import '../../models/delivery_status.dart';
import '../../models/order_record.dart';

@immutable
abstract class DeliveryEvent {
  const DeliveryEvent();
}

class LoadDeliveryHomeEvent extends DeliveryEvent {
  final String deliveryId;
  const LoadDeliveryHomeEvent(this.deliveryId);
}

class WatchDeliveryHomeEvent extends DeliveryEvent {
  final String deliveryId;
  const WatchDeliveryHomeEvent(this.deliveryId);
}

class DeliveryOrdersUpdatedEvent extends DeliveryEvent {
  final List<OrderRecord> assignedOrders;
  final List<OrderRecord> availableOrders;

  const DeliveryOrdersUpdatedEvent({
    required this.assignedOrders,
    required this.availableOrders,
  });
}

class AcceptOrderEvent extends DeliveryEvent {
  final String orderId;
  final String deliveryId;
  final String? deliveryName;

  const AcceptOrderEvent({
    required this.orderId,
    required this.deliveryId,
    this.deliveryName,
  });
}

class RejectOrderEvent extends DeliveryEvent {
  final String orderId;
  final String deliveryId;

  const RejectOrderEvent({
    required this.orderId,
    required this.deliveryId,
  });
}

class UpdateOrderStatusEvent extends DeliveryEvent {
  final String orderId;
  final DeliveryStatus currentStatus;
  final DeliveryStatus targetStatus;
  final String? deliveryPhoto;

  const UpdateOrderStatusEvent({
    required this.orderId,
    required this.currentStatus,
    required this.targetStatus,
    this.deliveryPhoto,
  });
}

class DismissNotificationEvent extends DeliveryEvent {
  const DismissNotificationEvent();
}
