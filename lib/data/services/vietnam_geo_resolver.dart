/// Resolves Vietnamese administrative place names to map coordinates.
///
/// The app needs coordinates for every address it stores, because the
/// delivery fee is distance-based and the courier navigates to a point —
/// an address at `0.0, 0.0` silently produces a zero fee and a broken
/// navigation route.
///
/// `assets/vietnam_wards.json` holds the official **post-2025 ward**
/// structure: one flat list of 3,321 communes/wards, each with a parent
/// province and a centroid (`geo.lat` / `geo.lon`). There is **no
/// district level any more** — "Quận 1", "Thanh Khê" and friends are
/// gone from the dataset.
///
/// That is why the address form no longer offers a district picker: the
/// administrative hierarchy is *province → ward* now, and offering a
/// district the app cannot resolve would only produce wrong coordinates.
///
/// The dataset is loaded once and cached for the lifetime of the process —
/// it is ~1 MB of JSON and every address form reads from it.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../domain/utils/text_normalizer.dart';

/// A resolved map point.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GeoPoint &&
          other.latitude == latitude &&
          other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';
}

/// A ward (or commune) with its centroid and its province.
class WardInfo {
  const WardInfo({
    required this.name,
    required this.province,
    required this.latitude,
    required this.longitude,
  });

  /// The ward's display name, e.g. "Bến Thành".
  final String name;

  /// The parent province's display name, e.g. "Hồ Chí Minh".
  final String province;

  /// The ward's centroid.
  final double latitude;
  final double longitude;

  /// The ward as a map point.
  GeoPoint get point => GeoPoint(latitude, longitude);
}

/// A province with its wards and its centroid.
class ProvinceInfo {
  const ProvinceInfo({
    required this.name,
    required this.wards,
    required this.centroid,
  });

  /// The province's display name, e.g. "Hồ Chí Minh".
  final String name;

  /// Every ward of the province, sorted by name.
  final List<WardInfo> wards;

  /// The mean of the province's ward centroids.
  final GeoPoint centroid;
}

/// Resolves place names against the bundled Vietnamese administrative
/// dataset.
class VietnamGeoResolver {
  VietnamGeoResolver._();

  static final VietnamGeoResolver instance = VietnamGeoResolver._();

  /// The asset that holds the ward dataset.
  static const String assetPath = 'assets/vietnam_wards.json';

  /// The in-flight load, so concurrent callers share one parse.
  Future<VietnamGeoResolver>? _loading;

  /// Province display name → province.
  Map<String, ProvinceInfo> _provinces = const <String, ProvinceInfo>{};

  /// Normalised ward name → ward (the first row wins for repeated names).
  Map<String, WardInfo> _byWardName = const <String, WardInfo>{};

  /// "province|ward" → ward.
  Map<String, WardInfo> _byProvinceWard = const <String, WardInfo>{};

  /// Whether the dataset has been parsed.
  bool get isLoaded => _provinces.isNotEmpty;

  /// Every province, sorted by name.
  List<ProvinceInfo> get provinces {
    final rows = _provinces.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    return rows;
  }

  /// Loads the dataset (once) and returns the resolver.
  Future<VietnamGeoResolver> ensureLoaded() {
    return _loading ??= _load();
  }

  Future<VietnamGeoResolver> _load() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! List) return this;

      final wards = <WardInfo>[];
      for (final entry in decoded.whereType<Map>()) {
        final row = Map<String, dynamic>.from(entry);
        final name = _readName(row['name']);
        // `parent` is `{id, level, name: {local, en, slug}}` — the
        // province name is one level deeper than the ward's own name.
        final parent = row['parent'];
        final province = _readName(parent is Map ? parent['name'] : null);
        final geo = row['geo'];
        final lat = _readDouble(geo is Map ? geo['lat'] : null);
        final lon = _readDouble(geo is Map ? geo['lon'] : null);
        if (name.isEmpty || lat == null || lon == null) continue;
        wards.add(
          WardInfo(
            name: name,
            province: province,
            latitude: lat,
            longitude: lon,
          ),
        );
      }

      // Group the wards by province.
      final buckets = <String, List<WardInfo>>{};
      for (final ward in wards) {
        buckets.putIfAbsent(ward.province, () => <WardInfo>[]).add(ward);
      }

      final provinces = <String, ProvinceInfo>{};
      for (final entry in buckets.entries) {
        final rows = entry.value..sort((a, b) => a.name.compareTo(b.name));
        provinces[entry.key] = ProvinceInfo(
          name: entry.key,
          wards: List<WardInfo>.unmodifiable(rows),
          centroid: GeoPoint(
            _mean(rows.map((w) => w.latitude)),
            _mean(rows.map((w) => w.longitude)),
          ),
        );
      }
      _provinces = provinces;

      _byWardName = <String, WardInfo>{
        for (final ward in wards)
          if (!_byWardName.containsKey(_key(ward.name))) _key(ward.name): ward,
      };
      _byProvinceWard = <String, WardInfo>{
        for (final ward in wards)
          '${_key(ward.province)}|${_key(ward.name)}': ward,
      };
    } catch (_) {
      // A missing or malformed asset must never crash the address form —
      // the caller simply gets no coordinates and falls back to the flat
      // delivery fee.
      _provinces = const <String, ProvinceInfo>{};
      _byWardName = const <String, WardInfo>{};
      _byProvinceWard = const <String, WardInfo>{};
    }
    return this;
  }

  /// The wards of a province, or an empty list when it is unknown.
  List<WardInfo> wardsOf(String province) =>
      _provinces[province]?.wards ?? const <WardInfo>[];

  /// The coordinates of a ward, or `null` when it is unknown.
  ///
  /// [ward] is matched on the normalised name, so "Bến Nghé" and
  /// "ben nghe" hit the same row. Pass [province] when it is known, so
  /// two wards with the same name in different provinces do not collide.
  GeoPoint? wardPoint(String ward, {String? province}) {
    if (province != null && province.isNotEmpty) {
      // The province is authoritative: a ward that does not exist in it
      // must not silently resolve to a same-named ward of another
      // province.
      return _byProvinceWard['${_key(province)}|${_key(ward)}']?.point;
    }
    return _byWardName[_key(ward)]?.point;
  }

  /// The centroid of a province.
  ///
  /// The dataset has no district level any more, so this is the mean of
  /// the province's ward centroids. It is the fallback used when a ward
  /// name is unknown or has been renamed by the 2025 reform.
  GeoPoint? provincePoint(String province) {
    if (province.isEmpty) return null;
    return _provinces[province]?.centroid;
  }

  /// The best available point for a full address.
  ///
  /// The ward wins; the province is the fallback.
  GeoPoint? resolve({
    String? ward,
    String? district,
    String? province,
  }) {
    if (ward != null && ward.isNotEmpty) {
      final wardHit = wardPoint(ward, province: province);
      if (wardHit != null) return wardHit;
    }
    if (province != null && province.isNotEmpty) {
      final provinceHit = provincePoint(province);
      if (provinceHit != null) return provinceHit;
    }
    if (district != null && district.isNotEmpty) {
      final districtHit = provincePoint(district);
      if (districtHit != null) return districtHit;
    }
    return null;
  }

  /// The lookup key: normalised and whitespace-collapsed.
  static String _key(String value) =>
      collapseWhitespace(stripDiacritics(value)).toLowerCase();

  static String _readName(Object? value) {
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final local = (map['local'] ?? '').toString().trim();
      if (local.isNotEmpty) return local;
      return (map['en'] ?? '').toString().trim();
    }
    return (value ?? '').toString().trim();
  }

  static double? _readDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse((value ?? '').toString().trim());
  }

  static double _mean(Iterable<double> values) {
    final list = values.toList();
    if (list.isEmpty) return 0;
    var sum = 0.0;
    for (final value in list) {
      sum += value;
    }
    return sum / list.length;
  }
}
