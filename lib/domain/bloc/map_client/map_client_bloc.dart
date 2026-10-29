import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../../data/services/route_service.dart';
import '../../models/driver_info.dart';
import '../../models/lat_lng_point.dart';
import '../../services/app_failure.dart';
import '../../services/realtime_service.dart';

part 'map_client_event.dart';
part 'map_client_state.dart';

/// MapClientBloc — manages the realtime map shown to the client while
/// they wait for the delivery (UC-03).
///
/// The bloc owns the [RealtimeService] subscription for the live order:
/// - subscribe to `/delicia/orders/{orderId}/shipperLocation` on init,
/// - listen for value changes and translate them into
///   [OnUpdateDeliveryPositionEvent]s,
/// - cancel the subscription on dispose via [disconnectSocket].
///
/// It also keeps the drawn route fresh. Rather than re-routing on every
/// GPS ping, a [Timer.periodic] nudges the lookup and [RouteService] gates
/// the actual HTTP call behind its `shouldRefetch` heuristic, so a car
/// creeping forward at walking pace doesn't burn through the OSRM quota.
class MapClientBloc extends Bloc<MapClientEvent, MapClientState> {
  MapClientBloc({
    required RealtimeService realtimeService,
    RouteService? routeService,
    Duration routeRefreshInterval = const Duration(seconds: 15),
  }) : _realtimeService = realtimeService,
       _routeService = routeService ?? RouteService(),
       _routeRefreshInterval = routeRefreshInterval,
       super(const MapClientState()) {
    on<OnReadyMapClientEvent>(_onReadyMap);
    on<OnMarkerClientEvent>(_onMarker);
    on<OnUpdateDeliveryPositionEvent>(_onUpdateDeliveryPosition);
    on<OnMockDeliveryPositionEvent>(_onMockDeliveryPosition);
    on<OnInitSocketEvent>(_onInitSocket);
    on<OnClearSocketEvent>(_onClearSocket);
    on<OnResetPolylineEvent>(_onResetPolyline);
    on<OnRouteLoadedEvent>(_onRouteLoaded);
    on<OnRouteFailedEvent>(_onRouteFailed);
    on<OnRealtimeErrorEvent>(_onRealtimeError);
  }

  final RealtimeService _realtimeService;
  final RouteService _routeService;
  final Duration _routeRefreshInterval;

  RealtimeSubscription? _realtimeSub;
  Timer? _routeTimer;

  /// Endpoints the currently displayed route was built from. Compared
  /// against the live markers to decide when a refetch is warranted.
  LatLngPoint? _routeOrigin;
  LatLngPoint? _routeDestination;
  bool _routeRequestInFlight = false;

  void _onReadyMap(OnReadyMapClientEvent event, Emitter<MapClientState> emit) {
    emit(state.copyWith(isReadyMapClient: true));
  }

  void _onMarker(OnMarkerClientEvent event, Emitter<MapClientState> emit) {
    emit(
      state.copyWith(
        markerClient: event.clientLatLng,
        markerDelivery: event.deliveryLatLng,
      ),
    );
    // Both endpoints are known now — draw a route straight away, then let
    // the periodic refresh keep pace with the courier.
    _refreshRoute(event.deliveryLatLng, event.clientLatLng);
  }

  void _onUpdateDeliveryPosition(
    OnUpdateDeliveryPositionEvent event,
    Emitter<MapClientState> emit,
  ) {
    final position = LatLngPoint(
      latitude: event.position.latitude,
      longitude: event.position.longitude,
    );
    _emitDeliveryPosition(position, emit);
    unawaited(_refreshRoute(position, state.markerClient));
  }

  void _onMockDeliveryPosition(
    OnMockDeliveryPositionEvent event,
    Emitter<MapClientState> emit,
  ) {
    // Simulation follows the already-loaded route geometry and should not
    // issue repeated OSRM requests as the mock marker advances.
    _emitDeliveryPosition(event.position, emit);
  }

  void _emitDeliveryPosition(
    LatLngPoint position,
    Emitter<MapClientState> emit,
  ) {
    final next = List<LatLngPoint>.from(state.polylineCoordinates);
    next.add(position);
    emit(
      state.copyWith(
        markerDelivery: position,
        polylineCoordinates: next,
      ),
    );
  }

  Future<void> _onInitSocket(
    OnInitSocketEvent event,
    Emitter<MapClientState> emit,
  ) async {
    await _disconnectPrevious();
    try {
      _realtimeSub = _realtimeService.subscribeOrder(event.orderId);
      _realtimeSub!.stream.listen(
        (update) {
          add(
            OnUpdateDeliveryPositionEvent(
              DeliveryPositionUpdate(
                orderId: update.orderId,
                latitude: update.latitude,
                longitude: update.longitude,
              ),
            ),
          );
        },
        onError: (Object e) {
          // Surface the error in the state so the UI can show a snack.
          add(OnRealtimeErrorEvent(e));
        },
      );

      _startRouteRefresh();
    } catch (e) {
      emit(
        state.copyWith(
          error: AppFailure(AppFailureCodes.realtimeSubscribe, '${e}'),
        ),
      );
    }
  }

  Future<void> _onClearSocket(
    OnClearSocketEvent event,
    Emitter<MapClientState> emit,
  ) async {
    await _disconnectPrevious();
    _routeOrigin = null;
    _routeDestination = null;
    emit(const MapClientState());
  }

  void _onResetPolyline(
    OnResetPolylineEvent event,
    Emitter<MapClientState> emit,
  ) {
    emit(state.copyWith(polylineCoordinates: const []));
  }

  void _onRouteLoaded(OnRouteLoadedEvent event, Emitter<MapClientState> emit) {
    emit(
      state.copyWith(
        routePolyline: event.points,
        routeDistanceMeters: event.distanceMeters,
        clearError: true,
      ),
    );
  }

  /// Swallows the failure on purpose: the previous geometry stays on the
  /// map and the user isn't nagged every refresh cycle.
  void _onRouteFailed(OnRouteFailedEvent event, Emitter<MapClientState> emit) {}

  void _onRealtimeError(
    OnRealtimeErrorEvent event,
    Emitter<MapClientState> emit,
  ) {
    emit(
      state.copyWith(
        error: AppFailure(AppFailureCodes.realtimeListener, '${event.error}'),
      ),
    );
  }

  void _startRouteRefresh() {
    _routeTimer?.cancel();
    _routeTimer = Timer.periodic(_routeRefreshInterval, (_) {
      if (isClosed) return;
      _refreshRoute(state.markerDelivery, state.markerClient);
    });
  }

  /// Fetches the courier → customer route, unless the cached one is still
  /// accurate enough. Runs outside the event pipeline (it's a plain async
  /// function whose result is fed back via `add`) so a slow HTTP call
  /// never blocks marker updates.
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

    if (_routeRequestInFlight) return;
    _routeRequestInFlight = true;
    try {
      final route = await _routeService.getRoute(
        origin: origin,
        destination: destination,
      );
      if (isClosed || route.isEmpty) return;
      _routeOrigin = origin;
      _routeDestination = destination;
      add(OnRouteLoadedEvent(route.points, route.distanceMeters));
    } catch (_) {
      add(const OnRouteFailedEvent());
    } finally {
      _routeRequestInFlight = false;
    }
  }

  /// Public hook for the screen's `dispose()` — cancels the subscription
  /// and drops all listeners so memory doesn't leak when the user
  /// navigates away.
  Future<void> disconnectSocket() => _disconnectPrevious();

  Future<void> _disconnectPrevious() async {
    _routeTimer?.cancel();
    _routeTimer = null;
    await _realtimeSub?.cancel();
    _realtimeSub = null;
  }

  @override
  Future<void> close() async {
    await _disconnectPrevious();
    _routeService.dispose();
    return super.close();
  }
}
