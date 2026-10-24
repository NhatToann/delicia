// UC-03 — MapClientBloc tests. Uses a fake RealtimeService.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/map_client/map_client_bloc.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:delicia/domain/services/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _NoopRealtime implements RealtimeService {
  @override
  Future<void> publishPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {}

  @override
  RealtimeSubscription subscribeOrder(String orderId) {
    final controller = StreamController<RealtimePositionUpdate>.broadcast();
    return RealtimeSubscription(
      controller: controller,
      cancelRaw: () async {
        await controller.close();
      },
    );
  }
}

void main() {
  group('MapClientBloc', () {
    blocTest<MapClientBloc, MapClientState>(
      'OnReadyMapClientEvent toggles isReadyMapClient',
      build: () => MapClientBloc(realtimeService: _NoopRealtime()),
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
      build: () => MapClientBloc(realtimeService: _NoopRealtime()),
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
      build: () => MapClientBloc(realtimeService: _NoopRealtime()),
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
