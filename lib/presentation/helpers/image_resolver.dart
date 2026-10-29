import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resolves a `picture` field from the catalog data into a Widget.
///
/// The catalogue stores the **absolute URL** of every image. The
/// database row is the only source of truth: no widget in the app
/// hardcodes an image path, so re-hosting a photo is a data change and
/// not a release.
///
/// Four shapes are accepted, in this order:
///
///   1. **A full `http(s)` URL** — the normal case. It is loaded with
///      [CachedNetworkImage], so the photo is downloaded once, cached on
///      disk and served from memory on every later visit.
///   2. **A local asset path** (`assets/…`, or the legacy relative form
///      `products/burger.jpg`) — kept so the bundled artwork and the
///      placeholder artwork still resolve.
///   3. **A base64 data URL** — used for small profile photos stored with the
///      user's Realtime Database profile when Firebase Storage is unavailable.
///   4. **Anything else** — falls back to [fallback].
///
/// The network path never shows a broken image: a failed download falls
/// back to [fallback] and a slow one shows a neutral placeholder.
class ImageResolver {
  const ImageResolver._();

  /// Root directory that holds the local assets shipped with the app.
  /// Must match the top-level folders registered in `pubspec.yaml`
  /// (`assets/logos/`, `assets/icons/`, `assets/categories/`,
  /// `assets/products/`, `assets/map/`). The Frave-style relative
  /// picture values (e.g. `products/burger-classic.jpg`) are resolved
  /// relative to this root.
  static const String _root = 'assets';

  /// Default fallback when the asset cannot be located.
  static const String defaultFallback = 'assets/icons/no-data.svg';

  /// Whether [picture] is a remote URL the app should download.
  static bool isRemote(String picture) {
    final value = picture.trim();
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Converts a [picture] value (asset-relative path, URL or empty) into
  /// a loadable asset path. Returns `null` if the value cannot be mapped
  /// to a local asset.
  static String? resolveAssetPath(String picture) {
    final value = picture.trim();
    if (value.isEmpty) return null;
    // Already a fully qualified asset path.
    if (value.startsWith('assets/')) return value;
    // Network URL — UI is expected to use [resolveWidget] which dispatches
    // to the cached network image instead.
    if (isRemote(value)) {
      return null;
    }
    // Strip a leading slash so `products/burger.png` works.
    final normalized = value.startsWith('/') ? value.substring(1) : value;
    return '$_root/$normalized';
  }

  /// Whether the app is running inside a `flutter test` run.
  ///
  /// `CachedNetworkImage` writes to the on-disk cache, which needs the
  /// `path_provider` plugin — a plugin that does not exist in the test
  /// harness, so every network image would throw
  /// `MissingPluginException`.
  ///
  /// On top of that, a test must not depend on the network at all: the
  /// golden tests would change every time the hosted artwork does. So in
  /// a test a hosted URL is mapped back to the **identical bundled
  /// asset** — the app ships the same photos under `assets/products/`
  /// and `assets/categories/`, byte for byte. The result is the same
  /// picture, without a request and without a plugin.
  static bool get _isTest => Platform.environment.containsKey('FLUTTER_TEST');

  /// The bundled copy of a catalogue image.
  ///
  /// Product image URLs are mirrored by their Unsplash/photo path id;
  /// Firebase-hosted category images retain their folder-based mapping.
  /// Returns null when no bundled mirror is known.
  static String? _localCopyOf(String url) {
    const externalMirrors = <String, String>{
      'photo-1568901346375-23c9450c58cd': 'burger-classic.jpg',
      'photo-1692737580547-b45bb4a02356': 'pizza-pepperoni.jpg',
      'photo-1604259596863-57153177d40b': 'poke-salmon-bowl.jpg',
      'photo-1730900737724-5b752e1ed3dd': 'fried-chicken.jpg',
      'photo-1546069901-ba9599a7e63c': 'poke-chicken-bowl.jpg',
      'photo-1570968915860-54d5c301fa9f': 'salted-caramel-latte.jpg',
      '376A8794-Edit_trim.jpg': 'matcha-cheesecake.jpg',
      'photo-1517701604599-bb29b565090c': 'vietnamese-iced-coffee.jpg',
      'photo-1512621776951-a57141f2eefd': 'green-goddess-salad.jpg',
      'photo-1617305855058-336d24456869': 'molten-chocolate-cake.jpg',
      'photo-1553979459-d2229ba7433a': 'burger-cheddar.jpg',
      'photo-1598182198871-d3f4ab4fd181': 'burger-cheddar.jpg',
      'photo-1550547660-d9450f859349': 'burger-bacon.jpg',
      'photo-1561758033-d89a9ad46330': 'burger-mushroom.jpg',
      'photo-1671522635501-f03491b207e6': 'burger-spicy-chicken.jpg',
      'photo-1513104890138-7c749659a591': 'pizza-margherita-wood.jpg',
      'photo-1579751626657-72bc17010498': 'pizza-veggie.jpg',
      'photo-1571407970349-bc81e7e96d47': 'pizza-four-cheese.jpg',
      'photo-1604382355076-af4b0eb60143': 'pizza-hawaiian.jpg',
      'photo-1541167760496-1628856ab772': 'drink-cappuccino.jpg',
      '0-1_2f43135a-b317-47d8-8f56-5e79f8a4265f.jpg': 'drink-peach-tea.jpg',
      'glass_2x_99dfa3d7-d14c-4db9-9f48-b20869b6fc5a.png':
          'drink-strawberry-soda.jpg',
      'photo-1571877227200-a0d98ea607e9': 'dessert-tiramisu.jpg',
      'photo-1606313564200-e75d5e30476c': 'dessert-brownie.jpg',
      'photo-1548848221-0c2e497ed557': 'dessert-macaron.jpg',
      'photo-1490645935967-10de6ba17061': 'healthy-quinoa-bowl.jpg',
      'photo-1547592180-85f173990554': 'healthy-chicken-salad.jpg',
      'photo-1511690743698-d9d85f2fbf38': 'healthy-avocado-bowl.jpg',
    };
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;
    final externalFile = externalMirrors[segments.last];
    if (externalFile != null) return '$_root/products/$externalFile';

    const host = 'delicia-60e0a.web.app';
    if (!url.contains(host)) return null;
    if (segments.length != 2) return null;
    final folder = segments.first;
    if (folder != 'products' && folder != 'categories') return null;
    final candidate = '$_root/$folder/${segments.last}';
    return candidate;
  }

  /// Builds a widget for [picture] using the [width] and [height] hints.
  /// `fit` defaults to [BoxFit.cover] which is what the catalog cards
  /// and carousels need.
  static Widget resolveWidget(
    String picture, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    String fallback = defaultFallback,
  }) {
    final value = picture.trim();

    if (value.isEmpty) {
      return _fallbackWidget(fallback, width, height);
    }

    if (value.startsWith('data:image/')) {
      final bytes = _decodeImageDataUrl(value);
      if (bytes == null) {
        return _fallbackWidget(fallback, width, height);
      }
      return Image.memory(
        bytes,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _fallbackWidget(fallback, width, height),
      );
    }

    // 1) Network URL — use the bundled copy whenever this catalogue photo
    //    has one, so product cards load immediately and remain available
    //    offline. Unknown URLs still use the network path.
    if (isRemote(value)) {
      final local = _localCopyOf(value);
      if (local != null) {
        return Image.asset(
          local,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _fallbackWidget(fallback, width, height),
        );
      }
      return _remoteImage(
        value,
        width: width,
        height: height,
        fit: fit,
        fallback: fallback,
      );
    }

    // 2) SVG asset.
    if (value.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        value.startsWith('assets/') ? value : '$_root/$value',
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: (_) => _fallbackWidget(fallback, width, height),
      );
    }

    // 3) Regular image asset.
    final path = resolveAssetPath(value);
    if (path == null) {
      return _fallbackWidget(fallback, width, height);
    }
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _fallbackWidget(fallback, width, height),
    );
  }

  static Uint8List? _decodeImageDataUrl(String value) {
    final comma = value.indexOf(',');
    if (comma < 0) return null;
    final metadata = value.substring(0, comma).toLowerCase();
    if (!const {
      'data:image/jpeg;base64',
      'data:image/png;base64',
      'data:image/webp;base64',
    }.contains(metadata)) {
      return null;
    }
    try {
      return base64Decode(value.substring(comma + 1));
    } on FormatException {
      return null;
    }
  }

  /// The remote image widget.
  ///
  /// In the app this is a [CachedNetworkImage]: the photo is downloaded
  /// once, written to the on-disk cache and served from memory on every
  /// later visit. In a test the disk cache is unavailable, so the plain
  /// [Image.network] is used — same request, no plugin.
  static Widget _remoteImage(
    String url, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    required String fallback,
  }) {
    if (_isTest) {
      final local = _localCopyOf(url);
      if (local != null) {
        return Image.asset(
          local,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => _fallbackWidget(fallback, width, height),
        );
      }
      return Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _fallbackWidget(fallback, width, height),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (_, _) => _placeholder(width, height),
      errorWidget: (_, _, _) => _fallbackWidget(fallback, width, height),
    );
  }

  static Widget _placeholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
    );
  }

  static Widget _fallbackWidget(
    String fallback,
    double? width,
    double? height,
  ) {
    // The fallback may itself be a hosted URL (the catalogue artwork lives
    // on Firebase), so it goes through the same resolution as any other
    // picture.
    if (isRemote(fallback)) {
      return _remoteImage(
        fallback,
        width: width,
        height: height,
        fit: BoxFit.contain,
        fallback: defaultFallback,
      );
    }
    if (fallback.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        fallback,
        width: width,
        height: height,
        fit: BoxFit.contain,
        placeholderBuilder: (_) => _missingWidget(width, height),
      );
    }
    return Image.asset(
      fallback,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _missingWidget(width, height),
    );
  }

  /// The neutral "there is no image" tile.
  static Widget _missingWidget(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined),
    );
  }
}
