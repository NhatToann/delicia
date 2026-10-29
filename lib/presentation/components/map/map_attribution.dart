import 'package:flutter/material.dart';

import '../../../data/env/environment.dart';

/// Always-visible map data and tile-provider attribution.
class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.88),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Text(
        Environment.tileAttribution,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 9, color: Color(0xFF4A4A4A)),
      ),
    ),
  );
}
