// UC-03 — MapDeliveryBloc tests.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/map_delivery/map_delivery_bloc.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:delicia/domain/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopTransport implements SocketTransport {
  final List<({String event, Map<String, dynamic> data})> emits = [];
  @override
  void connect() {}
  @override
  void disconnect() {}
  @override
  void emit(String event, Map<String, dynamic> data) {
    emits.add((event: event, data: data));
  }

  @override
  Stream<dynamic> on(String event) => const Stream.empty();
  @override
  bool get isConnected => false;
}

void main() {
  group('MapDeliveryBloc', () {
    blocTest<MapDeliveryBloc, MapDeliveryState>(
      'OnMapReadyEvent toggles isReadyMapDelivery',
      build: () => MapDeliveryBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(const OnMapReadyEvent()),
      expect: () => [
        isA<MapDeliveryState>().having(
          (s) => s.isReadyMapDelivery,
          'ready',
          true,
        ),
      ],
    );

    blocTest<MapDeliveryBloc, MapDeliveryState>(
      'OnMarkertsDeliveryEvent updates both markers',
      build: () => MapDeliveryBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(const OnMarkertsDeliveryEvent(
        LatLngPoint(latitude: 10, longitude: 20),
        LatLngPoint(latitude: 11, longitude: 21),
      )),
      expect: () => [
        isA<MapDeliveryState>()
            .having((s) => s.markerClient.latitude, 'cl lat', 10)
            .having((s) => s.markerDelivery.longitude, 'dl lng', 21),
      ],
    );

    blocTest<MapDeliveryBloc, MapDeliveryState>(
      'OnUpdateCurrentLocationEvent updates current + polyline',
      build: () => MapDeliveryBloc(
        socketService: SocketService(transport: _NoopTransport()),
      ),
      act: (bloc) => bloc.add(OnUpdateCurrentLocationEvent(
        const DeliveryPositionUpdate(
          orderId: 'o1',
          latitude: 12.0,
          longitude: 13.0,
        ),
      )),
      expect: () => [
        isA<MapDeliveryState>()
            .having((s) => s.currentLocation.latitude, 'lat', 12.0)
            .having((s) => s.currentLocation.longitude, 'lng', 13.0)
            .having((s) => s.polyline.length, 'polyline', 1),
      ],
    );
  });
}