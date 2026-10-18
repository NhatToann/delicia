import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Resolves a `picture` field from the catalog data into a Widget.
///
/// The Frave-style backend stored images as relative URLs
/// (`products/burger.png`). The project has been ported to use **local
/// assets** instead, so a picture value of `products/burger.png` is
/// resolved to `assets/products/burger.png`.
///
/// To support a smooth migration from a remote storage later, a fully
/// qualified URL (`http://…` / `https://…`) is also accepted and loaded
/// with [Image.network]. Everything else falls back to [fallback].
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

  /// Converts a [picture] value (asset-relative path, URL or empty) into
  /// a loadable asset path. Returns `null` if the value cannot be mapped
  /// to a local asset.
  static String? resolveAssetPath(String picture) {
    final value = picture.trim();
    if (value.isEmpty) return null;
    // Already a fully qualified asset path.
    if (value.startsWith('assets/')) return value;
    // Network URL — UI is expected to use [resolveWidget] which dispatches
    // to [Image.network] instead.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return null;
    }
    // Strip a leading slash so `products/burger.png` works.
    final normalized = value.startsWith('/') ? value.substring(1) : value;
    return '$_root/$normalized';
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

    // 1) Network URL — direct load.
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return Image.network(
        value,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) =>
            _fallbackWidget(fallback, width, height),
        loadingBuilder: (ctx, child, progress) {
          if (progress == null) return child;
          return _placeholder(width, height);
        },
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
      errorBuilder: (_, __, ___) =>
          _fallbackWidget(fallback, width, height),
    );
  }

  static Widget _placeholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF5F5F5),
    );
  }

  static Widget _fallbackWidget(String fallback, double? width, double? height) {
    if (fallback.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        fallback,
        width: width,
        height: height,
        fit: BoxFit.contain,
      );
    }
    return Image.asset(
      fallback,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: width,
        height: height,
        color: const Color(0xFFF5F5F5),
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
