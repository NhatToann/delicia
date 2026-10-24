import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/lat_lng_point.dart';
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
class MapClientBloc extends Bloc<MapClientEvent, MapClientState> {
  MapClientBloc({required RealtimeService realtimeService})
      : _realtimeService = realtimeService,
        super(const MapClientState()) {
    on<OnReadyMapClientEvent>(_onReadyMap);
    on<OnMarkerClientEvent>(_onMarker);
    on<OnUpdateDeliveryPositionEvent>(_onUpdateDeliveryPosition);
    on<OnInitSocketEvent>(_onInitSocket);
    on<OnClearSocketEvent>(_onClearSocket);
    on<OnResetPolylineEvent>(_onResetPolyline);
  }

  final RealtimeService _realtimeService;
  RealtimeSubscription? _realtimeSub;
  String? _activeOrderId;

  void _onReadyMap(OnReadyMapClientEvent event, Emitter<MapClientState> emit) {
    emit(state.copyWith(isReadyMapClient: true));
  }

  void _onMarker(OnMarkerClientEvent event, Emitter<MapClientState> emit) {
    emit(state.copyWith(
      markerClient: event.clientLatLng,
      markerDelivery: event.deliveryLatLng,
    ));
  }

  void _onUpdateDeliveryPosition(
    OnUpdateDeliveryPositionEvent event,
    Emitter<MapClientState> emit,
  ) {
    final next = List<LatLngPoint>.from(state.polylineCoordinates);
    next.add(LatLngPoint(
      latitude: event.position.latitude,
      longitude: event.position.longitude,
    ));
    emit(state.copyWith(
      markerDelivery: LatLngPoint(
        latitude: event.position.latitude,
        longitude: event.position.longitude,
      ),
      polylineCoordinates: next,
    ));
  }

  Future<void> _onInitSocket(
    OnInitSocketEvent event,
    Emitter<MapClientState> emit,
  ) async {
    await _disconnectPrevious();
    try {
      _activeOrderId = event.orderId;
      _realtimeSub = _realtimeService.subscribeOrder(event.orderId);
      _realtimeSub!.stream.listen(
        (update) {
          add(OnUpdateDeliveryPositionEvent(
            DeliveryPositionUpdate(
              orderId: update.orderId,
              latitude: update.latitude,
              longitude: update.longitude,
            ),
          ));
        },
        onError: (Object e) {
          // Surface the error in the state so the UI can show a snack.
          emit(state.copyWith(error: 'Realtime listener error: $e'));
        },
      );
    } catch (e) {
      emit(state.copyWith(error: 'Cannot subscribe to realtime: $e'));
    }
  }

  Future<void> _onClearSocket(
    OnClearSocketEvent event,
    Emitter<MapClientState> emit,
  ) async {
    await _disconnectPrevious();
    emit(const MapClientState());
  }

  void _onResetPolyline(
    OnResetPolylineEvent event,
    Emitter<MapClientState> emit,
  ) {
    emit(state.copyWith(polylineCoordinates: const []));
  }

  /// Public hook for the screen's `dispose()` — cancels the subscription
  /// and drops all listeners so memory doesn't leak when the user
  /// navigates away.
  Future<void> disconnectSocket() => _disconnectPrevious();

  Future<void> _disconnectPrevious() async {
    await _realtimeSub?.cancel();
    _realtimeSub = null;
    _activeOrderId = null;
  }

  @override
  Future<void> close() async {
    await _disconnectPrevious();
    return super.close();
  }
}