// UC-03 — shared test doubles for the map blocs.
//
// Both blocs now resolve a road route through [RouteService], so tests
// must inject a fake; otherwise a `blocTest` that sets markers would try
// to hit the live OSRM demo server and flake.

import 'package:delicia/data/services/route_service.dart';
import 'package:delicia/domain/models/lat_lng_point.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A [RouteService] backed by a canned response — no network, deterministic
/// geometry. Records every call so tests can assert on caching behaviour.
class FakeRouteService extends RouteService {
  FakeRouteService({
    this.points = const [
      LatLngPoint(latitude: 10.0, longitude: 20.0),
      LatLngPoint(latitude: 10.001, longitude: 19.998),
    ],
    this.distanceMeters = 1234.0,
    this.shouldFail = false,
  }) : super(
          httpClient: MockClient((_) async {
            if (shouldFail) throw http.ClientException('offline');
            return http.Response(_payload(distanceMeters), 200);
          }),
          baseUrl: 'https://route.test',
        );

  /// Geometry handed back on every successful lookup.
  final List<LatLngPoint> points;

  final double distanceMeters;

  /// When true every lookup throws, exercising the failure path.
  final bool shouldFail;

  /// (origin, destination) for every [getRoute] invocation.
  final List<({LatLngPoint origin, LatLngPoint destination})> requests = [];

  /// Overrides the default threshold-free heuristic result. Set to false
  /// to exercise the "cached route is still good" branch.
  bool? refetchOverride;

  @override
  Future<RouteResult> getRoute({
    required LatLngPoint origin,
    required LatLngPoint destination,
    bool forceRefresh = false,
  }) async {
    requests.add((origin: origin, destination: destination));
    if (shouldFail) {
      throw const RouteServiceException('fake failure');
    }
    return RouteResult(
      points: points,
      distanceMeters: distanceMeters,
      durationSeconds: distanceMeters / 10,
    );
  }

  @override
  bool shouldRefetch({
    required LatLngPoint origin,
    required LatLngPoint destination,
    LatLngPoint? lastRouteOrigin,
    LatLngPoint? lastRouteDestination,
    double minMoveMeters = 200,
  }) =>
      refetchOverride ?? super.shouldRefetch(
        origin: origin,
        destination: destination,
        lastRouteOrigin: lastRouteOrigin,
        lastRouteDestination: lastRouteDestination,
        minMoveMeters: minMoveMeters,
      );

  /// Builds a minimal valid OSRM payload. Only the fields
  /// [RouteService.parseRouteResponse] reads are included.
  static String _payload(double distance) =>
      '{"code":"Ok","routes":[{"geometry":"_c`|@_gayBgEnK",'
      '"distance":$distance,"duration":120.0}]}';
}