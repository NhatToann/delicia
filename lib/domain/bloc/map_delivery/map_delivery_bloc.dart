import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/lat_lng_point.dart';
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
class MapDeliveryBloc extends Bloc<MapDeliveryEvent, MapDeliveryState> {
  MapDeliveryBloc({
    required RealtimeService realtimeService,
    Duration emitInterval = const Duration(seconds: 5),
  })  : _realtimeService = realtimeService,
        _emitInterval = emitInterval,
        super(const MapDeliveryState()) {
    on<OnMapReadyEvent>(_onMapReady);
    on<OnMarkertsDeliveryEvent>(_onMarkerts);
    on<OnEmitLocationDeliveryEvent>(_onEmitLocation);
    on<OnUpdateCurrentLocationEvent>(_onUpdateCurrentLocation);
    on<OnDisconnectDeliveryEvent>(_onDisconnect);
    on<OnResetDeliveryPolylineEvent>(_onResetPolyline);
  }

  final RealtimeService _realtimeService;
  final Duration _emitInterval;
  Timer? _emitTimer;
  String? _activeOrderId;
  LatLngPoint _lastLocation = const LatLngPoint(latitude: 0, longitude: 0);

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
  }

  Future<void> _onEmitLocation(
    OnEmitLocationDeliveryEvent event,
    Emitter<MapDeliveryState> emit,
  ) async {
    _activeOrderId = event.orderId;
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
        emit(state.copyWith(error: 'Realtime publish failed: $e'));
      }
    });
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
    _activeOrderId = null;
  }

  void _onResetPolyline(
    OnResetDeliveryPolylineEvent event,
    Emitter<MapDeliveryState> emit,
  ) {
    emit(state.copyWith(polyline: const []));
  }

  @override
  Future<void> close() async {
    _emitTimer?.cancel();
    _emitTimer = null;
    return super.close();
  }
}