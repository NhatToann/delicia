import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/models/lat_lng_point.dart';
import '../../domain/services/app_failure.dart';

/// Raised when the routing backend can't be reached or answers with a
/// payload we can't decode into a route.
class RouteServiceException extends AppFailure {
  const RouteServiceException(super.code, [super.detail]);
}

/// A road-following route between two points.
class RouteResult {
  /// Every point the vehicle travels through, in order.
  final List<LatLngPoint> points;

  /// Total road distance in metres.
  final double distanceMeters;

  /// Estimated driving time in seconds. OSRM's free profile ignores live
  /// traffic, so treat this as a floor rather than a promise.
  final double durationSeconds;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  bool get isEmpty => points.isEmpty;
}

/// RouteService — resolves real road routes via the public OSRM demo
/// server (`router.project-osrm.org`).
///
/// Why OSRM?
/// - No API key and no billing, which keeps the stack consistent with the
///   OpenStreetMap tile choice already used in [Environment.tileServerUrl].
/// - It returns the full road geometry, so the map can draw a polyline
///   that follows streets instead of a straight line between markers.
///
/// Results are memoised per rounded endpoint pair and de-duplicated while
/// in flight, so the realtime map can ask for a route on every GPS tick
/// without hammering the server. Callers additionally gate refreshes with
/// [shouldRefetch] so a car creeping forward doesn't trigger a call for
/// every metre travelled.
class RouteService {
  RouteService({http.Client? httpClient, String? baseUrl})
      : _http = httpClient ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl;

  final http.Client _http;
  final String _baseUrl;

  /// Public demo server. Fine for development/portfolio traffic; point
  /// [baseUrl] at your own OSRM instance for production.
  static const String defaultBaseUrl = 'https://router.project-osrm.org';

  /// `driving` matches the car-based profile we render with.
  static const String _profile = 'driving';

  /// Endpoint precision used for cache keys — 1e-5 deg is roughly 1 m.
  static const double _cacheKeyPrecision = 100000;

  final Map<String, RouteResult> _cache = {};
  final Map<String, Future<RouteResult>> _inFlight = {};

  /// Returns the memoised route for these endpoints, or null if the route
  /// hasn't been fetched yet.
  RouteResult? cachedRoute({
    required LatLngPoint origin,
    required LatLngPoint destination,
  }) =>
      _cache[_cacheKey(origin, destination)];

  /// Whether a fresh lookup is justified for [origin] → [destination].
  ///
  /// [lastRouteOrigin] / [lastRouteDestination] are the endpoints the
  /// currently displayed route was built from. While the driver's own
  /// position barely moves and the drop-off address is unchanged, the
  /// drawn polyline is still accurate — so there is no point spending an
  /// OSRM request on it.
  bool shouldRefetch({
    required LatLngPoint origin,
    required LatLngPoint destination,
    LatLngPoint? lastRouteOrigin,
    LatLngPoint? lastRouteDestination,
    double minMoveMeters = 200,
  }) {
    if (lastRouteOrigin == null) return true;
    if (distanceMeters(origin, lastRouteOrigin) >= minMoveMeters) return true;
    // The customer address rarely moves, but if it does the route is stale.
    if (lastRouteDestination != null &&
        distanceMeters(destination, lastRouteDestination) >= minMoveMeters) {
      return true;
    }
    return false;
  }

  /// Fetches the road route between [origin] and [destination].
  ///
  /// Throws [RouteServiceException] on network failure, a non-200 status,
  /// or a payload without a decodable route.
  Future<RouteResult> getRoute({
    required LatLngPoint origin,
    required LatLngPoint destination,
    bool forceRefresh = false,
  }) async {
    if (origin == destination) {
      return const RouteResult(
        points: [],
        distanceMeters: 0,
        durationSeconds: 0,
      );
    }

    final key = _cacheKey(origin, destination);
    if (!forceRefresh) {
      final hit = _cache[key];
      if (hit != null) return hit;
      final pending = _inFlight[key];
      if (pending != null) return pending;
    }

    final future = _fetch(origin, destination);
    _inFlight[key] = future;
    try {
      final result = await future;
      _cache[key] = result;
      return result;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<RouteResult> _fetch(
    LatLngPoint origin,
    LatLngPoint destination,
  ) async {
    final uri = Uri.parse('$_baseUrl/route/v1/$_profile/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=polyline');

    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: const {'User-Agent': 'Delicia/1.0'})
          .timeout(const Duration(seconds: 10));
    } on TimeoutException catch (e) {
      throw RouteServiceException(AppFailureCodes.routeTimeout, '$e');
    } catch (e) {
      throw RouteServiceException(AppFailureCodes.routeFailed, '$e');
    }

    if (response.statusCode != 200) {
      throw RouteServiceException(
        AppFailureCodes.routeHttp,
        '${response.statusCode}',
      );
    }

    return parseRouteResponse(response.body);
  }

  /// Decodes an OSRM `/route` payload. Exposed so the decode path can be
  /// unit-tested against a captured response body.
  static RouteResult parseRouteResponse(String body) {
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } catch (e) {
      throw RouteServiceException(AppFailureCodes.routeMalformedDetail, '$e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const RouteServiceException(AppFailureCodes.routeMalformed);
    }

    if (decoded['code'] != 'Ok') {
      throw RouteServiceException(
        AppFailureCodes.routeRefused,
        '${decoded['code']}',
      );
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty || routes.first is! Map) {
      throw const RouteServiceException(AppFailureCodes.routeNoRoutes);
    }

    final route = routes.first as Map;
    final geometry = (route['geometry'] ?? '').toString();
    if (geometry.isEmpty) {
      throw const RouteServiceException(AppFailureCodes.routeNoGeometry);
    }

    return RouteResult(
      points: decodePolyline(geometry),
      distanceMeters: _toDouble(route['distance']),
      durationSeconds: _toDouble(route['duration']),
    );
  }

  /// Decodes a Google-style encoded polyline. OSRM replies with precision 5
  /// by default, which is what we request above.
  @visibleForTesting
  static List<LatLngPoint> decodePolyline(
    String encoded, {
    int precision = 5,
  }) {
    final factor = math.pow(10, precision).toInt();
    final points = <LatLngPoint>[];
    var index = 0;
    var lat = 0;
    var lng = 0;

    while (index < encoded.length) {
      final latChunk = _decodeChunk(encoded, index);
      if (latChunk == null) break;
      index = latChunk.nextIndex;
      lat += latChunk.delta;

      final lngChunk = _decodeChunk(encoded, index);
      if (lngChunk == null) break;
      index = lngChunk.nextIndex;
      lng += lngChunk.delta;

      points.add(LatLngPoint(
        latitude: lat / factor,
        longitude: lng / factor,
      ));
    }
    return points;
  }

  /// Reads one varint chunk starting at [start]. Returns null if the
  /// string ends mid-chunk so callers can stop on truncated payloads
  /// instead of throwing.
  static ({int nextIndex, int delta})? _decodeChunk(String encoded, int start) {
    var index = start;
    var result = 0;
    var shift = 0;
    int byte;

    do {
      if (index >= encoded.length) return null;
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);

    // Bit 0 carries the sign; the rest is a zig-zag encoded magnitude.
    return (nextIndex: index, delta: (result & 1) != 0 ? ~(result >> 1) : result >> 1);
  }

  /// Great-circle distance in metres.
  static double distanceMeters(LatLngPoint a, LatLngPoint b) {
    const earthRadius = 6371000.0;
    final lat1 = _toRadians(a.latitude);
    final lat2 = _toRadians(b.latitude);
    final dLat = lat2 - lat1;
    final dLng = _toRadians(b.longitude - a.longitude);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(lat1) * math.cos(lat2) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.min(1.0, math.sqrt(h)));
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180.0;

  static double _toDouble(Object? value) =>
      double.tryParse(value?.toString() ?? '') ?? 0.0;

  String _cacheKey(LatLngPoint origin, LatLngPoint destination) {
    String round(double v) => (v * _cacheKeyPrecision).round().toString();
    return '${round(origin.latitude)},${round(origin.longitude)}'
        '->${round(destination.latitude)},${round(destination.longitude)}';
  }

  /// Drops every memoised route and pending request. Used when the map is
  /// reset between orders.
  void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  void dispose() => _http.close();
}