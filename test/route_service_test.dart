// UC-03 — RouteService tests. The decode path is exercised against a
// captured OSRM payload so the suite stays offline and deterministic.

import 'package:delicia/data/services/route_service.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Trimmed but structurally identical to a real `router.project-osrm.org`
/// response: encoded geometry + distance/duration in metres/seconds.
const String _okPayload = '''
{
  "code": "Ok",
  "routes": [
    {
      "geometry": "_c`|@_gayBgEnK",
      "distance": 4530.6,
      "duration": 360.8
    }
  ]
}''';

void main() {
  group('RouteService.parseRouteResponse', () {
    test('decodes distance and duration', () {
      final result = RouteService.parseRouteResponse(_okPayload);
      expect(result.distanceMeters, closeTo(4530.6, 0.001));
      expect(result.durationSeconds, closeTo(360.8, 0.001));
    });

    test('decodes geometry into ordered coordinates', () {
      final result = RouteService.parseRouteResponse(_okPayload);
      expect(result.points.length, 2);
      // Encoded pair is (10.0, 20.0) then (10.001, 19.998).
      expect(result.points.first.latitude, closeTo(10.0, 1e-5));
      expect(result.points.first.longitude, closeTo(20.0, 1e-5));
      expect(result.points.last.latitude, closeTo(10.001, 1e-5));
      expect(result.points.last.longitude, closeTo(19.998, 1e-5));
    });

    test('round-trips a hand-encoded two-point polyline', () {
      // Encode (10.0, 20.0) then (+0.001, -0.002) using precision 5.
      final points = RouteService.decodePolyline('_c`|@_gayBgEnK');
      expect(points.length, 2);
      expect(points[0].latitude, closeTo(10.0, 1e-5));
      expect(points[0].longitude, closeTo(20.0, 1e-5));
      expect(points[1].latitude, closeTo(10.001, 1e-5));
      expect(points[1].longitude, closeTo(19.998, 1e-5));
    });

    test('stops instead of throwing on a truncated polyline', () {
      // Dropped mid-chunk after the first complete coordinate pair — the
      // decoder should keep what it has rather than throw.
      final points = RouteService.decodePolyline('_c`|@_gayB');
      expect(points.length, 1);
      expect(points.single.latitude, closeTo(10.0, 1e-5));
    });

    test('rejects a non-Ok code', () {
      expect(
        () => RouteService.parseRouteResponse('{"code":"NoRoute"}'),
        throwsA(isA<RouteServiceException>()),
      );
    });

    test('rejects an empty routes array', () {
      expect(
        () => RouteService.parseRouteResponse('{"code":"Ok","routes":[]}'),
        throwsA(isA<RouteServiceException>()),
      );
    });

    test('rejects malformed JSON', () {
      expect(
        () => RouteService.parseRouteResponse('not json'),
        throwsA(isA<RouteServiceException>()),
      );
    });
  });

  group('RouteService.getRoute', () {
    late List<Uri> requested;

    setUp(() => requested = []);

    RouteService buildService() {
      final client = MockClient((req) async {
        requested.add(req.url);
        return http.Response(_okPayload, 200);
      });
      return RouteService(httpClient: client, baseUrl: 'https://router.test');
    }

    test('requests lon,lat order from the routing backend', () async {
      final service = buildService();
      await service.getRoute(
        origin: const LatLngPoint(latitude: 10.7717, longitude: 106.7009),
        destination: const LatLngPoint(latitude: 10.7817, longitude: 106.7209),
      );

      expect(requested, hasLength(1));
      final url = requested.first;
      expect(url.host, 'https://router.test'.split('//').last);
      expect(url.path, '/route/v1/driving/106.7009,10.7717;106.7209,10.7817');
      expect(url.queryParameters['overview'], 'full');
      expect(url.queryParameters['geometries'], 'polyline');
    });

    test('serves the second identical request from cache', () async {
      final service = buildService();
      const origin = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      const destination =
          LatLngPoint(latitude: 10.7817, longitude: 106.7209);

      await service.getRoute(origin: origin, destination: destination);
      await service.getRoute(origin: origin, destination: destination);

      expect(requested, hasLength(1));
      expect(service.cachedRoute(origin: origin, destination: destination),
          isNotNull);
    });

    test('de-duplicates concurrent requests for the same pair', () async {
      final service = buildService();
      const origin = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      const destination =
          LatLngPoint(latitude: 10.7817, longitude: 106.7209);

      await Future.wait([
        service.getRoute(origin: origin, destination: destination),
        service.getRoute(origin: origin, destination: destination),
      ]);

      expect(requested, hasLength(1));
    });

    test('short-circuits when origin equals destination', () async {
      final service = buildService();
      const same = LatLngPoint(latitude: 10.7717, longitude: 106.7009);

      final result = await service.getRoute(origin: same, destination: same);

      expect(requested, isEmpty);
      expect(result.isEmpty, isTrue);
      expect(result.distanceMeters, 0);
    });

    test('forceRefresh bypasses the cache', () async {
      final service = buildService();
      const origin = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      const destination =
          LatLngPoint(latitude: 10.7817, longitude: 106.7209);

      await service.getRoute(origin: origin, destination: destination);
      await service.getRoute(
        origin: origin,
        destination: destination,
        forceRefresh: true,
      );

      expect(requested, hasLength(2));
    });

    test('throws on a non-200 response', () async {
      final service = RouteService(
        httpClient: MockClient((_) async => http.Response('nope', 503)),
        baseUrl: 'https://router.test',
      );

      expect(
        () => service.getRoute(
          origin: const LatLngPoint(latitude: 1, longitude: 2),
          destination: const LatLngPoint(latitude: 3, longitude: 4),
        ),
        throwsA(isA<RouteServiceException>()),
      );
    });

    test('clearCache drops memoised routes', () async {
      final service = buildService();
      const origin = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      const destination =
          LatLngPoint(latitude: 10.7817, longitude: 106.7209);

      await service.getRoute(origin: origin, destination: destination);
      service.clearCache();

      expect(service.cachedRoute(origin: origin, destination: destination),
          isNull);
    });
  });

  group('RouteService.shouldRefetch', () {
    final service = RouteService();
    const start = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
    const destination = LatLngPoint(latitude: 10.7817, longitude: 106.7209);

    test('always refetches when there is no previous route', () {
      expect(
        service.shouldRefetch(origin: start, destination: destination),
        isTrue,
      );
    });

    test('does not refetch for sub-metre jitter', () {
      expect(
        service.shouldRefetch(
          origin: const LatLngPoint(latitude: 10.77171, longitude: 106.70091),
          destination: destination,
          lastRouteOrigin: start,
          lastRouteDestination: destination,
        ),
        isFalse,
      );
    });

    test('refetches once the driver moved past the threshold', () {
      expect(
        service.shouldRefetch(
          // ~111 m north — still under the 200 m default.
          origin: const LatLngPoint(latitude: 10.7727, longitude: 106.7009),
          destination: destination,
          lastRouteOrigin: start,
          lastRouteDestination: destination,
        ),
        isFalse,
      );
      expect(
        service.shouldRefetch(
          // ~555 m north — past the threshold.
          origin: const LatLngPoint(latitude: 10.7767, longitude: 106.7009),
          destination: destination,
          lastRouteOrigin: start,
          lastRouteDestination: destination,
        ),
        isTrue,
      );
    });

    test('refetches when the customer address moved', () {
      expect(
        service.shouldRefetch(
          origin: start,
          destination: const LatLngPoint(
            latitude: 10.8000,
            longitude: 106.7009,
          ),
          lastRouteOrigin: start,
          lastRouteDestination: destination,
        ),
        isTrue,
      );
    });
  });

  group('RouteService.distanceMeters', () {
    test('is zero for identical points', () {
      const p = LatLngPoint(latitude: 10.7717, longitude: 106.7009);
      expect(RouteService.distanceMeters(p, p), 0);
    });

    test('matches the known HCMC one-degree latitude span', () {
      const a = LatLngPoint(latitude: 10.0, longitude: 106.0);
      const b = LatLngPoint(latitude: 10.01, longitude: 106.0);
      // 0.01 deg latitude is ~1112 m anywhere on earth.
      expect(RouteService.distanceMeters(a, b), closeTo(1112, 10));
    });
  });
}