part of 'map_client_bloc.dart';

@immutable
abstract class MapClientEvent {
  const MapClientEvent();
}

class OnReadyMapClientEvent extends MapClientEvent {
  const OnReadyMapClientEvent();
}

class OnMarkerClientEvent extends MapClientEvent {
  final LatLngPoint deliveryLatLng;
  final LatLngPoint clientLatLng;
  const OnMarkerClientEvent(this.deliveryLatLng, this.clientLatLng);
}

class OnUpdateDeliveryPositionEvent extends MapClientEvent {
  final DeliveryPositionUpdate position;
  const OnUpdateDeliveryPositionEvent(this.position);
}

class OnInitSocketEvent extends MapClientEvent {
  final String orderId;
  const OnInitSocketEvent(this.orderId);
}

class OnClearSocketEvent extends MapClientEvent {
  const OnClearSocketEvent();
}

class OnResetPolylineEvent extends MapClientEvent {
  const OnResetPolylineEvent();
}