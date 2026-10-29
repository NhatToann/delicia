import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_map/flutter_map.dart';

import '../env/environment.dart';

/// Persistent disk cache for map tiles actively requested by flutter_map.
///
/// OSM's public raster service requires clients to cache viewed tiles and is
/// best-effort. This cache stores only tiles requested for the visible map;
/// it never prefetches areas. Previously viewed regions can render from disk
/// on later visits and during temporary network failures.
abstract final class MapTileCache {
  static final CacheManager? _cacheManager = kIsWeb
      ? null
      : CacheManager(
          Config(
            'delicia-map-tiles',
            stalePeriod: const Duration(days: 7),
            maxNrOfCacheObjects: 800,
          ),
        );

  static TileProvider createProvider() => _PersistentTileProvider(
    cacheManager: _cacheManager,
    headers: {'User-Agent': Environment.tileUserAgent},
  );
}

class _PersistentTileProvider extends TileProvider {
  _PersistentTileProvider({
    required this.cacheManager,
    required super.headers,
  });

  final CacheManager? cacheManager;

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      CachedNetworkImageProvider(
        getTileUrl(coordinates, options),
        cacheManager: cacheManager,
        headers: headers,
      );
}
