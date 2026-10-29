part of 'map_delivery_bloc.dart';

@immutable
class MapDeliveryState {
  /// Urban delivery speed used to turn road distance into an ETA.
  static const double assumedSpeedKmh = 25;

  final bool isReadyMapDelivery;

  /// The customer's drop-off point.
  final LatLngPoint markerClient;

  /// The restaurant / pickup point. Kept distinct from the driver so the
  /// map can show where the order is being collected from.
  final LatLngPoint markerDelivery;

  /// The driver's live GPS position.
  final LatLngPoint currentLocation;

  /// Breadcrumb of every position the driver has reported. Drawn dimmed
  /// underneath the live route so the courier's progress is visible.
  final List<LatLngPoint> polyline;

  /// Road-following route from the driver to the customer (OSRM).
  final List<LatLngPoint> routePolyline;

  /// Remaining road distance in metres. Null until a route resolves.
  final double? routeDistanceMeters;

  /// Courier details, mocked until the backend exposes them.
  final DriverInfo? driver;

  /// The last failure, carrying a stable code the UI can translate.
  final AppFailure? error;

  const MapDeliveryState({
    this.isReadyMapDelivery = false,
    this.markerClient = const LatLngPoint(latitude: 0, longitude: 0),
    this.markerDelivery = const LatLngPoint(latitude: 0, longitude: 0),
    this.currentLocation = const LatLngPoint(latitude: 0, longitude: 0),
    this.polyline = const [],
    this.routePolyline = const [],
    this.routeDistanceMeters,
    this.driver,
    this.error,
  });

  /// Minutes left until arrival, or null while the route is unknown.
  int? get etaMinutes {
    final meters = routeDistanceMeters;
    if (meters == null) return null;
    return ((meters / 1000) / assumedSpeedKmh * 60).ceil();
  }

  /// The active timeline checkpoint for the driver's own sheet.
  ///
  /// Drivers never see the client-side `placed`/`preparing` stages — they
  /// only join once the order is dispatched — so the timeline starts at
  /// [OrderStage.dispatched] and advances once the driver starts moving.
  OrderStage get stage => polyline.isEmpty
      ? OrderStage.dispatched
      : OrderStage.onTheWay;

  /// Remaining distance, formatted for the card ("1.2 km" / "340 m").
  String get remainingDistanceLabel {
    final meters = routeDistanceMeters;
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  MapDeliveryState copyWith({
    bool? isReadyMapDelivery,
    LatLngPoint? markerClient,
    LatLngPoint? markerDelivery,
    LatLngPoint? currentLocation,
    List<LatLngPoint>? polyline,
    List<LatLngPoint>? routePolyline,
    double? routeDistanceMeters,
    DriverInfo? driver,
    AppFailure? error,
    bool clearError = false,
  }) {
    return MapDeliveryState(
      isReadyMapDelivery: isReadyMapDelivery ?? this.isReadyMapDelivery,
      markerClient: markerClient ?? this.markerClient,
      markerDelivery: markerDelivery ?? this.markerDelivery,
      currentLocation: currentLocation ?? this.currentLocation,
      polyline: polyline ?? this.polyline,
      routePolyline: routePolyline ?? this.routePolyline,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      driver: driver ?? this.driver,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapDeliveryState &&
          other.isReadyMapDelivery == isReadyMapDelivery &&
          other.markerClient == markerClient &&
          other.markerDelivery == markerDelivery &&
          other.currentLocation == currentLocation &&
          other.routeDistanceMeters == routeDistanceMeters &&
          other.driver == driver &&
          other.error == error &&
          _samePoints(other.polyline, polyline) &&
          _samePoints(other.routePolyline, routePolyline));

  @override
  int get hashCode => Object.hash(
        isReadyMapDelivery,
        markerClient,
        markerDelivery,
        currentLocation,
        routeDistanceMeters,
        driver,
        error,
        Object.hashAll(polyline),
        Object.hashAll(routePolyline),
      );

  static bool _samePoints(List<LatLngPoint> a, List<LatLngPoint> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}