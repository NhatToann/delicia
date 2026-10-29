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

/// Local-only position update used by the client map's route preview. Unlike
/// realtime courier positions, this never triggers another route lookup.
class OnMockDeliveryPositionEvent extends MapClientEvent {
  final LatLngPoint position;
  const OnMockDeliveryPositionEvent(this.position);
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

/// Emitted once a route lookup resolves, either from the initial fetch or
/// from a periodic refresh as the courier moves.
class OnRouteLoadedEvent extends MapClientEvent {
  final List<LatLngPoint> points;
  final double distanceMeters;

  const OnRouteLoadedEvent(this.points, this.distanceMeters);
}

/// Emitted when the route lookup fails. Carries no message so the map can
/// keep the previous geometry on screen — a failed refresh shouldn't wipe
/// the polyline the user is already looking at.
class OnRouteFailedEvent extends MapClientEvent {
  const OnRouteFailedEvent();
}

/// Emitted when the realtime listener errors. Routed through the event
/// pipeline because `emit` is only valid while its handler is still
/// running, and the failure arrives later from the socket stream.
class OnRealtimeErrorEvent extends MapClientEvent {
  final Object error;
  const OnRealtimeErrorEvent(this.error);
}
