import 'package:flutter/foundation.dart';

/// Lightweight immutable (lat, lng) record used by the map blocs so they
/// don't have to depend on any third-party map package directly. The
/// map widget (`flutter_map`) uses `latlong2.LatLng`; conversion happens
/// at the widget layer.
@immutable
class LatLngPoint {
  final double latitude;
  final double longitude;
  const LatLngPoint({required this.latitude, required this.longitude});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LatLngPoint &&
          other.latitude == latitude &&
          other.longitude == longitude);

  @override
  int get hashCode => Object.hash(latitude, longitude);
}