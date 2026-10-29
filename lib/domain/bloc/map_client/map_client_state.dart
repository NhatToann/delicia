part of 'map_client_bloc.dart';

@immutable
class MapClientState {
  /// Urban delivery speed used to turn road distance into an ETA.
  /// Deliberately a constant — OSRM's free profile ignores live traffic,
  /// so a single assumed average keeps the countdown stable instead of
  /// jittering every time the route is refetched.
  static const double assumedSpeedKmh = 25;

  final bool isReadyMapClient;

  /// Where the customer's order is being delivered to.
  final LatLngPoint markerClient;

  /// Where the courier is right now.
  final LatLngPoint markerDelivery;

  /// Every position the courier has reported — the breadcrumb trail.
  final List<LatLngPoint> polylineCoordinates;

  /// Road-following route from the courier to the customer. Sourced from
  /// `RouteService` (OSRM), so it bends along streets instead of cutting
  /// straight across the map. Empty until the first fetch resolves.
  final List<LatLngPoint> routePolyline;

  /// Road distance still to travel, in metres. Null until a route lands,
  /// so the UI can tell "unknown" apart from "0 m left".
  final double? routeDistanceMeters;

  /// Courier details. Mocked until the backend exposes them.
  final DriverInfo? driver;

  /// The last failure, carrying a stable code the UI can translate.
  final AppFailure? error;

  const MapClientState({
    this.isReadyMapClient = false,
    this.markerClient = const LatLngPoint(latitude: 0, longitude: 0),
    this.markerDelivery = const LatLngPoint(latitude: 0, longitude: 0),
    this.polylineCoordinates = const [],
    this.routePolyline = const [],
    this.routeDistanceMeters,
    this.driver,
    this.error,
  });

  /// Minutes left until arrival, derived from [routeDistanceMeters].
  /// Null while the route is unknown.
  int? get etaMinutes {
    final meters = routeDistanceMeters;
    if (meters == null) return null;
    return ((meters / 1000) / assumedSpeedKmh * 60).ceil();
  }

  /// The active checkpoint for the timeline. The client only reaches the
  /// live map once an order is [OrderRecord.canTrackDelivery], so the
  /// courier is already assigned; before their first GPS ping arrives we
  /// show "Dispatched", and the moment they start moving it's "On the way".
  OrderStage get stage => polylineCoordinates.isEmpty
      ? OrderStage.dispatched
      : OrderStage.onTheWay;

  /// Distance left, formatted for the driver card ("1.2 km" / "340 m").
  String get remainingDistanceLabel {
    final meters = routeDistanceMeters;
    if (meters == null) return '—';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  MapClientState copyWith({
    bool? isReadyMapClient,
    LatLngPoint? markerClient,
    LatLngPoint? markerDelivery,
    List<LatLngPoint>? polylineCoordinates,
    List<LatLngPoint>? routePolyline,
    double? routeDistanceMeters,
    DriverInfo? driver,
    AppFailure? error,
    bool clearError = false,
  }) {
    return MapClientState(
      isReadyMapClient: isReadyMapClient ?? this.isReadyMapClient,
      markerClient: markerClient ?? this.markerClient,
      markerDelivery: markerDelivery ?? this.markerDelivery,
      polylineCoordinates: polylineCoordinates ?? this.polylineCoordinates,
      routePolyline: routePolyline ?? this.routePolyline,
      routeDistanceMeters: routeDistanceMeters ?? this.routeDistanceMeters,
      driver: driver ?? this.driver,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MapClientState &&
          other.isReadyMapClient == isReadyMapClient &&
          other.markerClient == markerClient &&
          other.markerDelivery == markerDelivery &&
          other.routeDistanceMeters == routeDistanceMeters &&
          other.driver == driver &&
          other.error == error &&
          _samePoints(other.polylineCoordinates, polylineCoordinates) &&
          _samePoints(other.routePolyline, routePolyline));

  @override
  int get hashCode => Object.hash(
        isReadyMapClient,
        markerClient,
        markerDelivery,
        routeDistanceMeters,
        driver,
        error,
        Object.hashAll(polylineCoordinates),
        Object.hashAll(routePolyline),
      );

  /// Deep list comparison so a refetch that returns the same geometry
  /// doesn't trigger an extra rebuild.
  static bool _samePoints(List<LatLngPoint> a, List<LatLngPoint> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}