import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../data/services/route_service.dart';
import '../../models/driver_info.dart';
import '../../models/lat_lng_point.dart';
import '../../services/app_failure.dart';
import '../../services/realtime_service.dart';

part 'map_delivery_event.dart';
part 'map_delivery_state.dart';

/// MapDeliveryBloc — manages the realtime map shown to the delivery
/// driver (UC-03). It owns:
/// - the customer's LatLng (where the package needs to go),
/// - the driver's current location,
/// - the polyline that traces the route,
/// - a periodic emit of the driver's position to the realtime backend
///   ([RealtimeService], backed by Firebase RTDB).
///
/// Like [MapClientBloc] it keeps the drawn route in sync with the driver
/// via [RouteService], refreshing on a timer and letting the service's
/// `shouldRefetch` heuristic suppress requests while the driver is barely
/// moving.
class MapDeliveryBloc extends Bloc<MapDeliveryEvent, MapDeliveryState> {
  MapDeliveryBloc({
    required RealtimeService realtimeService,
    RouteService? routeService,
    Duration emitInterval = const Duration(seconds: 5),
    Duration routeRefreshInterval = const Duration(seconds: 15),
  })  : _realtimeService = realtimeService,
        _routeService = routeService ?? RouteService(),
        _emitInterval = emitInterval,
        _routeRefreshInterval = routeRefreshInterval,
        super(const MapDeliveryState()) {
    on<OnMapReadyEvent>(_onMapReady);
    on<OnMarkertsDeliveryEvent>(_onMarkerts);
    on<OnEmitLocationDeliveryEvent>(_onEmitLocation);
    on<OnUpdateCurrentLocationEvent>(_onUpdateCurrentLocation);
    on<OnDisconnectDeliveryEvent>(_onDisconnect);
    on<OnResetDeliveryPolylineEvent>(_onResetPolyline);
    on<OnDeliveryRouteLoadedEvent>(_onDeliveryRouteLoaded);
    on<OnDeliveryRouteFailedEvent>(_onDeliveryRouteFailed);
    on<OnDeliveryPublishErrorEvent>(_onDeliveryPublishError);
  }

  final RealtimeService _realtimeService;
  final RouteService _routeService;
  final Duration _emitInterval;
  final Duration _routeRefreshInterval;

  Timer? _emitTimer;
  Timer? _routeTimer;
  String? _activeOrderId;
  LatLngPoint _lastLocation = const LatLngPoint(latitude: 0, longitude: 0);

  /// Endpoints the currently displayed route was built from.
  LatLngPoint? _routeOrigin;
  LatLngPoint? _routeDestination;

  void _onMapReady(OnMapReadyEvent event, Emitter<MapDeliveryState> emit) {
    emit(state.copyWith(isReadyMapDelivery: true));
  }

  void _onMarkerts(
    OnMarkertsDeliveryEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    emit(state.copyWith(
      markerClient: event.clientLatLng,
      markerDelivery: event.deliveryLatLng,
    ));
    // Both endpoints are known — route from wherever the driver is now.
    _refreshRoute(
      _lastLocation.latitude == 0 && _lastLocation.longitude == 0
          ? event.deliveryLatLng
          : _lastLocation,
      event.clientLatLng,
    );
  }

  Future<void> _onEmitLocation(
    OnEmitLocationDeliveryEvent event,
    Emitter<MapDeliveryState> emit,
  ) async {
    _activeOrderId = event.orderId;
    emit(state.copyWith(driver: DriverInfo.mockFor(event.orderId)));

    _emitTimer?.cancel();
    _emitTimer = Timer.periodic(_emitInterval, (_) async {
      if (_activeOrderId == null) return;
      if (_lastLocation.latitude == 0 && _lastLocation.longitude == 0) return;
      try {
        await _realtimeService.publishPosition(
          orderId: _activeOrderId!,
          latitude: _lastLocation.latitude,
          longitude: _lastLocation.longitude,
        );
      } catch (e) {
        add(OnDeliveryPublishErrorEvent(e));
      }
    });

    _startRouteRefresh();
  }

  void _onUpdateCurrentLocation(
    OnUpdateCurrentLocationEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    _lastLocation = LatLngPoint(
      latitude: event.position.latitude,
      longitude: event.position.longitude,
    );
    final next = List<LatLngPoint>.from(state.polyline);
    next.add(_lastLocation);
    emit(state.copyWith(
      currentLocation: _lastLocation,
      polyline: next,
    ));
  }

  Future<void> _onDisconnect(
    OnDisconnectDeliveryEvent event,
    Emitter<MapDeliveryState> emit,
  ) async {
    _emitTimer?.cancel();
    _emitTimer = null;
    _routeTimer?.cancel();
    _routeTimer = null;
    _activeOrderId = null;
    _routeOrigin = null;
    _routeDestination = null;
  }

  void _onResetPolyline(
    OnResetDeliveryPolylineEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    emit(state.copyWith(polyline: const []));
  }

  void _onDeliveryRouteLoaded(
    OnDeliveryRouteLoadedEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    emit(state.copyWith(
      routePolyline: event.points,
      routeDistanceMeters: event.distanceMeters,
      clearError: true,
    ));
  }

  void _onDeliveryRouteFailed(
    OnDeliveryRouteFailedEvent event,
    Emitter<MapDeliveryState> emit,
  ) {}

  void _onDeliveryPublishError(
    OnDeliveryPublishErrorEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    emit(state.copyWith(
      error: AppFailure(AppFailureCodes.realtimePublish, '${event.error}'),
    ));
  }

  void _startRouteRefresh() {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(_routeRefreshInterval, (_) {
      if (isClosed) return;
      _refreshRoute(state.currentLocation, state.markerClient);
    });
  }

  /// Fetches the driver → customer route unless the cached one is still
  /// accurate. Runs outside the event pipeline and feeds the result back
  /// through `add` so a slow HTTP call never blocks GPS updates.
  Future<void> _refreshRoute(
    LatLngPoint origin,
    LatLngPoint destination,
  ) async {
    if (origin.latitude == 0 && origin.longitude == 0) return;
    if (destination.latitude == 0 && destination.longitude == 0) return;

    if (!_routeService.shouldRefetch(
      origin: origin,
      destination: destination,
      lastRouteOrigin: _routeOrigin,
      lastRouteDestination: _routeDestination,
    )) {
      return;
    }

    try {
      final route = await _routeService.getRoute(
        origin: origin,
        destination: destination,
      );
      if (isClosed || route.isEmpty) return;
      _routeOrigin = origin;
      _routeDestination = destination;
      add(OnDeliveryRouteLoadedEvent(route.points, route.distanceMeters));
    } catch (_) {
      add(const OnDeliveryRouteFailedEvent());
    }
  }

  @override
  Future<void> close() async {
    _emitTimer?.cancel();
    _emitTimer = null;
    _routeTimer?.cancel();
    _routeTimer = null;
    _routeService.dispose();
    return super.close();
  }
}