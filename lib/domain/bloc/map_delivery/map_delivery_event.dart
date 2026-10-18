part of 'map_delivery_bloc.dart';

@immutable
abstract class MapDeliveryEvent {
  const MapDeliveryEvent();
}

class OnMapReadyEvent extends MapDeliveryEvent {
  const OnMapReadyEvent();
}

class OnMarkertsDeliveryEvent extends MapDeliveryEvent {
  final LatLngPoint clientLatLng;
  final LatLngPoint deliveryLatLng;
  const OnMarkertsDeliveryEvent(
    this.clientLatLng,
    this.deliveryLatLng,
  );
}

class OnEmitLocationDeliveryEvent extends MapDeliveryEvent {
  final String orderId;
  const OnEmitLocationDeliveryEvent(this.orderId);
}

class OnUpdateCurrentLocationEvent extends MapDeliveryEvent {
  final DeliveryPositionUpdate position;
  const OnUpdateCurrentLocationEvent(this.position);
}

class OnDisconnectDeliveryEvent extends MapDeliveryEvent {
  const OnDisconnectDeliveryEvent();
}

class OnResetDeliveryPolylineEvent extends MapDeliveryEvent {
  const OnResetDeliveryPolylineEvent();
}