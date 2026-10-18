part of 'map_client_bloc.dart';

@immutable
class MapClientState {
  final bool isReadyMapClient;
  final LatLngPoint markerClient;
  final LatLngPoint markerDelivery;
  final List<LatLngPoint> polylineCoordinates;
  final String? error;

  const MapClientState({
    this.isReadyMapClient = false,
    this.markerClient = const LatLngPoint(latitude: 0, longitude: 0),
    this.markerDelivery = const LatLngPoint(latitude: 0, longitude: 0),
    this.polylineCoordinates = const [],
    this.error,
  });

  MapClientState copyWith({
    bool? isReadyMapClient,
    LatLngPoint? markerClient,
    LatLngPoint? markerDelivery,
    List<LatLngPoint>? polylineCoordinates,
    String? error,
    bool clearError = false,
  }) {
    return MapClientState(
      isReadyMapClient: isReadyMapClient ?? this.isReadyMapClient,
      markerClient: markerClient ?? this.markerClient,
      markerDelivery: markerDelivery ?? this.markerDelivery,
      polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
      error: clearError ? null : (error ?? this.error),
    );
  }
}