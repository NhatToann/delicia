// UC-03 — MapClientBloc tests. Uses a fake RealtimeService and a
// deterministic fake RouteService so tests are fully offline.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/map_client/map_client_bloc.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:delicia/domain/services/app_failure.dart';
import 'package:delicia/domain/services/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_route_service.dart';

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
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      act: (bloc) => bloc.add(const OnReadyMapClientEvent()),
      expect: () => [
        isA<MapClientState>().having((s) => s.isReadyMapClient, 'ready', true),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnMarkerClientEvent updates both markers and fetches route',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      act: (bloc) => bloc.add(
        const OnMarkerClientEvent(
          LatLngPoint(latitude: 1, longitude: 2),
          LatLngPoint(latitude: 3, longitude: 4),
        ),
      ),
      // Two emissions: the markers, then the route that the fake service
      // resolves for them.
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.markerDelivery.latitude, 'dl lat', 1)
            .having((s) => s.markerClient.longitude, 'cl lng', 4),
        isA<MapClientState>()
            .having((s) => s.routePolyline.isNotEmpty, 'route', true)
            .having((s) => s.routeDistanceMeters, 'distance', 1234.0),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnUpdateDeliveryPositionEvent moves the delivery marker',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      act: (bloc) => bloc.add(
        OnUpdateDeliveryPositionEvent(
          const DeliveryPositionUpdate(
            orderId: 'o1',
            latitude: 11.0,
            longitude: 22.0,
          ),
        ),
      ),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.markerDelivery.latitude, 'lat', 11.0)
            .having((s) => s.markerDelivery.longitude, 'lng', 22.0)
            .having((s) => s.polylineCoordinates.length, 'polyline', 1),
      ],
    );

    final mockPositionRouteService = FakeRouteService();
    blocTest<MapClientBloc, MapClientState>(
      'OnMockDeliveryPositionEvent moves marker and extends trail without routing',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: mockPositionRouteService,
      ),
      seed: () => const MapClientState(
        routePolyline: [
          LatLngPoint(latitude: 10.0, longitude: 106.0),
          LatLngPoint(latitude: 10.1, longitude: 106.1),
        ],
      ),
      act: (bloc) => bloc.add(
        const OnMockDeliveryPositionEvent(
          LatLngPoint(latitude: 10.05, longitude: 106.05),
        ),
      ),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.markerDelivery.latitude, 'mock latitude', 10.05)
            .having((s) => s.markerDelivery.longitude, 'mock longitude', 106.05)
            .having((s) => s.polylineCoordinates, 'breadcrumb trail', [
              const LatLngPoint(latitude: 10.05, longitude: 106.05),
            ])
            .having((s) => s.routePolyline.length, 'route stays visible', 2),
      ],
      verify: (_) => expect(mockPositionRouteService.requests, isEmpty),
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnRouteLoadedEvent stores geometry + distance and clears errors',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      seed: () => const MapClientState(error: AppFailure('stale')),
      act: (bloc) => bloc.add(
        const OnRouteLoadedEvent([
          LatLngPoint(latitude: 5, longitude: 6),
          LatLngPoint(latitude: 5.1, longitude: 6.1),
        ], 4200),
      ),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.routePolyline.length, 'route points', 2)
            .having((s) => s.routeDistanceMeters, 'distance', 4200)
            .having((s) => s.error, 'error cleared', isNull),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnRouteFailedEvent keeps the previous geometry',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      seed: () => const MapClientState(
        routePolyline: [
          LatLngPoint(latitude: 5, longitude: 6),
          LatLngPoint(latitude: 5.1, longitude: 6.1),
        ],
        routeDistanceMeters: 900,
      ),
      act: (bloc) => bloc.add(const OnRouteFailedEvent()),
      // The handler deliberately swallows the event — no emission at all.
      expect: () => const <MapClientState>[],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnResetPolylineEvent clears the courier trail but keeps the route',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      seed: () => const MapClientState(
        polylineCoordinates: [LatLngPoint(latitude: 1, longitude: 2)],
        routePolyline: [
          LatLngPoint(latitude: 1, longitude: 2),
          LatLngPoint(latitude: 1.5, longitude: 2.5),
        ],
        routeDistanceMeters: 700,
      ),
      act: (bloc) => bloc.add(const OnResetPolylineEvent()),
      expect: () => [
        isA<MapClientState>()
            .having((s) => s.polylineCoordinates, 'trail', isEmpty)
            .having((s) => s.routePolyline.length, 'route kept', 2)
            .having((s) => s.routeDistanceMeters, 'distance kept', 700),
      ],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnClearSocketEvent resets the whole state',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      seed: () => const MapClientState(
        isReadyMapClient: true,
        markerClient: LatLngPoint(latitude: 3, longitude: 4),
        markerDelivery: LatLngPoint(latitude: 1, longitude: 2),
        polylineCoordinates: [LatLngPoint(latitude: 1, longitude: 2)],
        routePolyline: [
          LatLngPoint(latitude: 1, longitude: 2),
          LatLngPoint(latitude: 3, longitude: 4),
        ],
        routeDistanceMeters: 500,
      ),
      act: (bloc) => bloc.add(const OnClearSocketEvent()),
      expect: () => [const MapClientState()],
    );

    blocTest<MapClientBloc, MapClientState>(
      'OnInitSocketEvent waits for real courier metadata',
      build: () => MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(),
      ),
      act: (bloc) => bloc.add(const OnInitSocketEvent('order-42')),
      expect: () => <MapClientState>[],
      verify: (bloc) => expect(bloc.state.driver, isNull),
    );

    test('a failed route lookup leaves the map usable', () async {
      final bloc = MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: FakeRouteService(shouldFail: true),
      );
      bloc.add(
        const OnMarkerClientEvent(
          LatLngPoint(latitude: 1, longitude: 2),
          LatLngPoint(latitude: 3, longitude: 4),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Markers are set, route is simply empty — no crash, no error snack.
      expect(
        bloc.state.markerClient,
        const LatLngPoint(latitude: 3, longitude: 4),
      );
      expect(bloc.state.routePolyline, isEmpty);
      expect(bloc.state.error, isNull);
      await bloc.close();
    });

    test('the route is not refetched while the courier barely moves', () async {
      final routes = FakeRouteService();
      final bloc = MapClientBloc(
        realtimeService: _NoopRealtime(),
        routeService: routes,
        routeRefreshInterval: const Duration(milliseconds: 20),
      );
      bloc.add(
        const OnMarkerClientEvent(
          LatLngPoint(latitude: 10.7717, longitude: 106.7009),
          LatLngPoint(latitude: 10.7817, longitude: 106.7209),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // One call for the initial marker event; the periodic ticks are all
      // suppressed by the 200 m movement threshold.
      expect(routes.requests, hasLength(1));
      await bloc.close();
    });
  });
}
