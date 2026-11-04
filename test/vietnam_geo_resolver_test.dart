import 'package:delicia/data/services/vietnam_geo_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the Vietnamese ward resolver.
///
/// The delivery fee is distance-based, so every stored address has to
/// carry a real map point. The resolver is what turns a "Phường / Xã"
/// selection into coordinates, using the bundled
/// `assets/vietnam_wards.json` dataset (the official post-2025 ward
/// structure: province → ward, no district level any more).
///
/// The tests read the real asset, so they also protect the asset itself:
/// a dataset that loses its `geo` block would silently break every fee.
void main() {
  late VietnamGeoResolver resolver;

  setUpAll(() async {
    // The resolver reads its dataset through `rootBundle`, which needs
    // the test binding to resolve the bundled asset.
    TestWidgetsFlutterBinding.ensureInitialized();
    resolver = await VietnamGeoResolver.instance.ensureLoaded();
  });

  group('dataset', () {
    test('loads the ward dataset', () {
      expect(resolver.isLoaded, isTrue);
      expect(resolver.provinces, isNotEmpty);
    });

    test('every province has at least one ward', () {
      for (final province in resolver.provinces) {
        expect(
          province.wards,
          isNotEmpty,
          reason: '${province.name} has no ward',
        );
      }
    });

    test('every ward carries a usable centroid', () {
      for (final province in resolver.provinces) {
        for (final ward in province.wards) {
          expect(ward.latitude, inInclusiveRange(-90, 90));
          expect(ward.longitude, inInclusiveRange(-180, 180));
          // Vietnam spans roughly 8°N–24°N. The longitude range is wider
          // than the mainland because of the islands (Trường Sa sits at
          // ~111.9°E).
          expect(ward.latitude, inInclusiveRange(8, 24));
          expect(ward.longitude, inInclusiveRange(102, 112));
        }
      }
    });

    test('a province centroid is inside Vietnam', () {
      for (final province in resolver.provinces) {
        expect(province.centroid.latitude, inInclusiveRange(8, 24));
        expect(province.centroid.longitude, inInclusiveRange(102, 112));
      }
    });
  });

  group('wardPoint', () {
    test('resolves a ward by its exact name', () {
      final point = resolver.wardPoint('Bến Thành');
      expect(point, isNotNull);
      expect(point!.latitude, greaterThan(0));
      expect(point.longitude, greaterThan(0));
    });

    test('ignores diacritics and casing', () {
      final withDiacritics = resolver.wardPoint('Bến Thành');
      final without = resolver.wardPoint('ben thanh');
      final upper = resolver.wardPoint('BEN THANH');

      expect(without, isNotNull);
      expect(without, withDiacritics);
      expect(upper, withDiacritics);
    });

    test('scopes the lookup to the province when it is given', () {
      // "Yên Hòa" exists in three provinces.
      final hanoi = resolver.wardPoint('Yên Hòa', province: 'Hà Nội');
      final ngheAn = resolver.wardPoint('Yên Hòa', province: 'Nghệ An');

      expect(hanoi, isNotNull);
      expect(ngheAn, isNotNull);
      // The two provinces are hundreds of kilometres apart.
      expect((hanoi!.latitude - ngheAn!.latitude).abs(), greaterThan(1));
    });

    test('a province that does not contain the ward resolves to null', () {
      // "Bến Thành" only exists in Hồ Chí Minh.
      expect(
        resolver.wardPoint('Bến Thành', province: 'Hà Nội'),
        isNull,
      );
    });

    test('an unknown ward resolves to null', () {
      expect(resolver.wardPoint('Không Tồn Tại 123'), isNull);
    });
  });

  group('provincePoint', () {
    test('resolves a province centroid', () {
      final point = resolver.provincePoint('Hồ Chí Minh');
      expect(point, isNotNull);
      expect(point!.latitude, inInclusiveRange(10, 12));
      expect(point.longitude, inInclusiveRange(106, 107));
    });

    test('an unknown province resolves to null', () {
      expect(resolver.provincePoint('Atlantis'), isNull);
      expect(resolver.provincePoint(''), isNull);
    });
  });

  group('resolve', () {
    test('prefers the ward over the province', () {
      final wardOnly = resolver.resolve(ward: 'Bến Thành');
      final provinceOnly = resolver.resolve(province: 'Hồ Chí Minh');

      expect(wardOnly, isNotNull);
      expect(provinceOnly, isNotNull);
      expect(wardOnly, isNot(provinceOnly));
    });

    test('falls back to the province when the ward is unknown', () {
      final point = resolver.resolve(
        ward: 'Phường Không Tồn Tại',
        province: 'Hồ Chí Minh',
      );

      expect(point, isNotNull);
      expect(point, resolver.provincePoint('Hồ Chí Minh'));
    });

    test('returns null when nothing is known', () {
      expect(resolver.resolve(), isNull);
      expect(
        resolver.resolve(ward: 'X', district: 'Y', province: 'Atlantis'),
        isNull,
      );
    });
  });
}
