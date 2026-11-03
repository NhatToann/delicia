import '../../../data/env/environment.dart';
import 'lat_lng_point.dart';

/// Geofence and coordinate helpers for Ho Chi Minh City.
///
/// Delicia operates in Ho Chi Minh City. Any coordinates outside HCMC
/// (for example from an Android emulator defaulting to US or Russia, or a device without GPS)
/// are automatically mapped to a valid location in Ho Chi Minh City.
class HcmcLocation {
  HcmcLocation._();

  /// Approximate HCMC bounding box.
  static const double minLat = 10.35;
  static const double maxLat = 11.15;
  static const double minLng = 106.35;
  static const double maxLng = 107.05;

  /// Default center in HCMC (Bếp Delicia, Bến Nghé, Quận 1).
  static const LatLngPoint defaultCenter = LatLngPoint(
    latitude: Environment.restaurantLatitude,
    longitude: Environment.restaurantLongitude,
  );

  /// Default driver starting location (Bếp Delicia, Quận 1).
  static const LatLngPoint defaultDriverLocation = LatLngPoint(
    latitude: Environment.restaurantLatitude,
    longitude: Environment.restaurantLongitude,
  );

  /// Checks whether [lat] and [lng] fall inside the Ho Chi Minh City area.
  static bool isInHcmc(double lat, double lng) {
    if (lat == 0.0 && lng == 0.0) return false;
    return lat >= minLat && lat <= maxLat && lng >= minLng && lng <= maxLng;
  }

  /// Sanitizes coordinates: if outside HCMC, returns a valid location in HCMC.
  static LatLngPoint sanitize(double lat, double lng, {LatLngPoint? fallback}) {
    if (isInHcmc(lat, lng)) {
      return LatLngPoint(latitude: lat, longitude: lng);
    }
    return fallback ?? defaultDriverLocation;
  }
}

