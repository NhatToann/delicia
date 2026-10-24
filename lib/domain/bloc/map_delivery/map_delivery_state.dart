part of 'map_delivery_bloc.dart';

@immutable
class MapDeliveryState {
  final bool isReadyMapDelivery;
  final LatLngPoint markerClient;
  final LatLngPoint markerDelivery;
  final LatLngPoint currentLocation;
  final List<LatLngPoint> polyline;
  final String? error;

  const MapDeliveryState({
    this.isReadyMapDelivery = false,
    this.markerClient = const LatLngPoint(latitude: 0, longitude: 0),
    this.markerDelivery = const LatLngPoint(latitude: 0, longitude: 0),
    this.currentLocation = const LatLngPoint(latitude: 0, longitude: 0),
    this.polyline = const [],
    this.error,
  });

  MapDeliveryState copyWith({
    bool? isReadyMapDelivery,
    LatLngPoint? markerClient,
    LatLngPoint? markerDelivery,
    LatLngPoint? currentLocation,
    List<LatLngPoint>? polyline,
    String? error,
    bool clearError = false,
  }) {
    return MapDeliveryState(
      isReadyMapDelivery: isReadyMapDelivery ?? this.isReadyMapDelivery,
      markerClient: markerClient ?? this.markerClient,
      markerDelivery: markerDelivery ?? this.markerDelivery,
      currentLocation: currentLocation ?? this.currentLocation,
      polyline: polyline ?? this.polyline,
      error: clearError ? null : (error ?? this.error),
    );
  }
}