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

/// Emitted once a route lookup resolves, either from the initial fetch or
/// from a periodic refresh as the driver advances.
class OnDeliveryRouteLoadedEvent extends MapDeliveryEvent {
  final List<LatLngPoint> points;
  final double distanceMeters;

  const OnDeliveryRouteLoadedEvent(this.points, this.distanceMeters);
}

/// Emitted when the route lookup fails. Keeps the previous geometry on the
/// map instead of blanking the route.
class OnDeliveryRouteFailedEvent extends MapDeliveryEvent {
  const OnDeliveryRouteFailedEvent();
}

/// Emitted when a periodic publish fails — routed through the event
/// pipeline because `emit` is only valid while its handler is running and
/// the failure surfaces later from the timer callback.
class OnDeliveryPublishErrorEvent extends MapDeliveryEvent {
  final Object error;
  const OnDeliveryPublishErrorEvent(this.error);
}