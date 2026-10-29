import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../domain/models/lat_lng_point.dart';

/// RoutePolylineLayer — draws the courier's route the way Grab does: a
/// thick translucent-white casing under a coloured line, so the path stays
/// legible over both pale map tiles and dark park areas.
///
/// Two polylines are stacked in a single layer so they always share the
/// same [PolylineLayer] ordering — splitting them across layers would let
/// markers or other overlays slip between the casing and the line.
class RoutePolylineLayer extends StatelessWidget {
  final List<LatLngPoint> points;

  /// Colour of the main route line.
  final Color color;

  /// Draw the white casing underneath. Disable when overlaying the route
  /// on a busy background where the casing just muddies the line.
  final bool outlined;

  /// Opacity of the casing, kept below 1 so the map still reads through.
  final double outlineOpacity;

  const RoutePolylineLayer({
    super.key,
    required this.points,
    this.color = const Color(0xFF00B14F),
    this.outlined = true,
    this.outlineOpacity = 0.9,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      // A single point can't form a line — skip the layer entirely rather
      // than emitting a degenerate polyline flutter_map would warn about.
      return const SizedBox.shrink();
    }

    final latLngs = points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return PolylineLayer<Object>(
      polylines: [
        if (outlined)
          Polyline(
            points: latLngs,
            color: Colors.white.withValues(alpha: outlineOpacity),
            strokeWidth: 9,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
            borderStrokeWidth: 0,
          ),
        Polyline(
          points: latLngs,
          color: color,
          strokeWidth: 5,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      ],
    );
  }
}

/// BreadcrumbTrailLayer — renders the path the courier has *already*
/// travelled. Drawn dimmed beneath the live route so the user can see how
/// far along the trip they are, not just where it's heading.
class BreadcrumbTrailLayer extends StatelessWidget {
  final List<LatLngPoint> points;
  final Color color;

  const BreadcrumbTrailLayer({
    super.key,
    required this.points,
    this.color = const Color(0xFF9AA0A6),
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    return PolylineLayer<Object>(
      polylines: [
        Polyline(
          points: points.map((p) => LatLng(p.latitude, p.longitude)).toList(),
          color: color.withValues(alpha: 0.55),
          strokeWidth: 3,
          strokeCap: StrokeCap.round,
          strokeJoin: StrokeJoin.round,
        ),
      ],
    );
  }
}