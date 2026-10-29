// UC-03 — MapDeliveryBloc tests.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/map_delivery/map_delivery_bloc.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:delicia/domain/services/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_route_service.dart';

class _FakeRealtime implements RealtimeService {
  final List<({String orderId, double latitude, double longitude})>
      published = [];

  @override
  Future<void> publishPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    published.add((orderId: orderId, latitude: latitude, longitude: longitude));
  }

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
  group('MapDeliveryBloc', () {
    blocTest<MapDeliveryBloc, MapDeliveryState>(
      'OnMapReadyEvent toggles isReadyMapDelivery',
      build: () => MapDeliveryBloc(realtimeService: _FakeRealtime()),
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
        realtimeService: _FakeRealtime(),
        routeService: FakeRouteService(),
      ),
      act: (bloc) => bloc.add(const OnMarkertsDeliveryEvent(
        LatLngPoint(latitude: 10, longitude: 20),
        LatLngPoint(latitude: 11, longitude: 21),
      )),
      expect: () => [
        isA<MapDeliveryState>()
            .having((s) => s.markerClient.latitude, 'cl lat', 10)
            .having((s) => s.markerDelivery.longitude, 'dl lng', 21),
        // Route fetched from FakeRouteService.
        isA<MapDeliveryState>()
            .having((s) => s.routePolyline.isNotEmpty, 'route', true)
            .having((s) => s.routeDistanceMeters, 'distance', 1234.0),
      ],
    );

    blocTest<MapDeliveryBloc, MapDeliveryState>(
      'OnUpdateCurrentLocationEvent updates current + polyline',
      build: () => MapDeliveryBloc(realtimeService: _FakeRealtime()),
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

    test('OnEmitLocationDeliveryEvent publishes to realtime every tick',
        () async {
      final realtime = _FakeRealtime();
      final bloc = MapDeliveryBloc(
        realtimeService: realtime,
        emitInterval: const Duration(milliseconds: 30),
      );
      bloc.add(OnUpdateCurrentLocationEvent(
        const DeliveryPositionUpdate(
          orderId: 'o1',
          latitude: 1.0,
          longitude: 2.0,
        ),
      ));
      bloc.add(const OnEmitLocationDeliveryEvent('o1'));
      // Let the periodic timer fire at least twice.
      await Future<void>.delayed(const Duration(milliseconds: 90));
      await bloc.close();
      expect(realtime.published.length, greaterThanOrEqualTo(1));
      expect(realtime.published.first.orderId, 'o1');
      expect(realtime.published.first.latitude, 1.0);
      expect(realtime.published.first.longitude, 2.0);
    });
  });
}
