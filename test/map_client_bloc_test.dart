// UC-03 — MapClientBloc tests. Uses a fake SocketService.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/map_client/map_client_bloc.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:delicia/domain/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopTransport implements SocketTransport {
  @override
  void connect() {}
  @override
  void disconnect() {}
  @override
  void emit(String event, Map<String, dynamic> data) {}
  @override
  Stream<dynamic> on(String event) => const Stream.empty();
  @override
  bool get isConnected => false;
}

void main() {
  group('MapClientBloc', () {
    blocTest<MapClientBloc, MapClientState>(
      'OnReadyMapClientEvent toggles isReadyMapClient',
      build: () => MapClientBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(const OnReadyMapClientEvent()),
      expect: () => [
        isA<MapClientState>().having(
          (s) => s.isReadyMapClient,
          'ready',
          true,
        ),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnMarkerClientEvent updates both markers',
      build: () => MapClientBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(const OnMarkerClientEvent(
        LatLngPoint(latitude: 1, longitude: 2),
        LatLngPoint(latitude: 3, longitude: 4),
      )),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.markerDelivery.latitude, 'dl lat', 1)
            .having((s) => s.markerClient.longitude, 'cl lng', 4),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnUpdateDeliveryPositionEvent moves the delivery marker',
      build: () => MapClientBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(OnUpdateDeliveryPositionEvent(
        const DeliveryPositionUpdate(
          orderId: 'o1',
          latitude: 11.0,
          longitude: 22.0,
        ),
      )),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.markerDelivery.latitude, 'lat', 11.0)
            .having((s) => s.markerDelivery.longitude, 'lng', 22.0)
            .having((s) => s.polylineCoordinates.length, 'polyline', 1),
      ],
    );
  });
}