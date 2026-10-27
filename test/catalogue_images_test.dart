// Guards the catalogue-image contract (Task 1).
//
// The rule the app follows is simple: **every dish photo is a URL stored in
// Firebase**, never a hardcoded local asset path in a widget. The Realtime
// Database row (`products/{id}/picture`) is the only source of truth, so
// re-hosting a photo is a data change and not a release.
//
// Three ways that rule can silently break, all covered here:
//
//   1. a row whose `picture` is not an absolute `http(s)` URL — the app
//      would fall back to a local asset and the "no hardcoding" promise
//      would be a lie;
//   2. a hosted URL whose file is not bundled locally — the app works
//      online, but the offline mirror (`ImageResolver._localCopyOf`) has
//      nothing to fall back to, so the dish renders as a grey placeholder
//      in widget/golden tests and on a cold cache;
//   3. the seed tooling (`scripts/apply_catalogue_images.dart`) drifting
//      away from the canonical catalogue (`scripts/catalog_reference.json`)
//      — the two tables name the same photos, so they must agree.
//
// The canonical catalogue is `scripts/catalog_reference.json`; the live
// database is written from it by `scripts/apply_catalogue_images.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Firebase Hosting root the catalogue imagery is served from.
const String _host = 'delicia-60e0a.web.app';

/// The folders a catalogue image may live in.
const List<String> _folders = <String>['products', 'categories'];

void main() {
  late Map<String, dynamic> catalog;
  late Map<String, dynamic> products;
  late Map<String, dynamic> categories;

  setUpAll(() {
    final raw = File('scripts/catalog_reference.json').readAsStringSync();
    catalog = jsonDecode(raw) as Map<String, dynamic>;
    products = catalog['products'] as Map<String, dynamic>;
    categories = catalog['categories'] as Map<String, dynamic>;
  });

  group('every catalogue photo is a hosted URL', () {
    test('every product row carries an absolute http(s) URL', () {
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final picture = (row['picture'] ?? '').toString();

        expect(
          picture,
          startsWith('https://'),
          reason: '${entry.key} must store an absolute URL, got "$picture"',
        );
      }
    });

    test('every category row carries an absolute http(s) URL', () {
      for (final entry in categories.entries) {
        final row = entry.value as Map<String, dynamic>;
        final picture = (row['picture'] ?? '').toString();

        expect(
          picture,
          startsWith('https://'),
          reason: '${entry.key} must store an absolute URL, got "$picture"',
        );
      }
    });

    test('every product photo is hosted on the catalogue CDN', () {
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        expect(
          (row['picture'] as String),
          contains(_host),
          reason: '${entry.key} must point at the Firebase-hosted catalogue',
        );
      }
    });

    test('no dish photo is a local asset path', () {
      // The whole point of the task: the picture lives in the database as a
      // URL. A row that carries `assets/products/...` is a regression.
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final picture = (row['picture'] as String);

        expect(
          picture,
          isNot(contains('assets/')),
          reason: '${entry.key} must not hardcode a local asset path',
        );
      }
    });

    test('every product photo sits in the products folder', () {
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        expect(
          uri.pathSegments,
          hasLength(2),
          reason: '${entry.key} must point at /products/<file>',
        );
        expect(uri.pathSegments.first, 'products');
      }
    });

    test('every category photo sits in the categories folder', () {
      for (final entry in categories.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        expect(uri.pathSegments, hasLength(2));
        expect(uri.pathSegments.first, 'categories');
      }
    });
  });

  group('every hosted photo has a bundled offline mirror', () {
    test('each product photo is bundled under assets/products/', () {
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        final local = 'assets/${uri.pathSegments.join('/')}';

        expect(
          File(local).existsSync(),
          isTrue,
          reason: '${entry.key} needs a bundled copy at $local so the app '
              'still renders it offline and the golden tests stay '
              'deterministic',
        );
      }
    });

    test('each category photo is bundled under assets/categories/', () {
      for (final entry in categories.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        final local = 'assets/${uri.pathSegments.join('/')}';

        expect(
          File(local).existsSync(),
          isTrue,
          reason: '${entry.key} needs a bundled copy at $local',
        );
      }
    });

    test('no bundled mirror is empty', () {
      // A zero-byte file would render as a broken image rather than a
      // fallback, so the size has to be checked, not just the presence.
      for (final folder in _folders) {
        final dir = Directory('assets/$folder');
        if (!dir.existsSync()) continue;

        for (final entity in dir.listSync()) {
          if (entity is! File) continue;
          expect(
            entity.lengthSync(),
            greaterThan(0),
            reason: '${entity.path} is empty',
          );
        }
      }
    });
  });

  group('the seed tooling agrees with the canonical catalogue', () {
    test('the photo mapping in the script matches the catalogue', () {
      // `scripts/apply_catalogue_images.dart` declares its own table so
      // it can run without importing the app. The two tables name the same
      // photos, so they must never drift apart.
      final script =
          File('scripts/apply_catalogue_images.dart').readAsStringSync();

      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        final fileName = uri.pathSegments.last;

        expect(
          script,
          contains("'${entry.key}': '$fileName'"),
          reason: 'the seed script must map ${entry.key} to $fileName',
        );
      }
    });

    test('the script declares no product the catalogue does not', () {
      final script =
          File('scripts/apply_catalogue_images.dart').readAsStringSync();
      final mapping = RegExp(r"'p\d+':\s*'([^']+)'").allMatches(script);

      for (final match in mapping) {
        final id = match.group(0)!.split(':').first.replaceAll("'", '').trim();
        expect(
          products.containsKey(id),
          isTrue,
          reason: 'the seed script maps $id, which the catalogue omits',
        );
      }
    });
  });

  group('the dish and its photo agree', () {
    // A photo that does not match the dish is the defect the user asked
    // to fix: a "Gà Chiên" card must not show a burger.
    /// The photo file each dish must use.
    const Map<String, String> expected = <String, String>{
      'p01': 'burger-classic.jpg',
      'p02': 'pizza-pepperoni.jpg',
      'p03': 'poke-salmon-bowl.png',
      'p04': 'fried-chicken.png',
      'p05': 'poke-bowl.png',
      'p06': 'coffee.jpg',
      'p07': 'dessert-cake.jpg',
      'p08': 'coffee.jpg',
      'p09': 'salad-caesar.jpg',
      'p10': 'dessert-cake.jpg',
    };

    test('each dish points at its own photo', () {
      for (final entry in expected.entries) {
        final row = products[entry.key] as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);

        expect(
          uri.pathSegments.last,
          entry.value,
          reason: '${entry.key} must use ${entry.value}',
        );
      }
    });

    test('no two dishes share a photo unless they are the same food', () {
      // The two coffees and the two desserts legitimately share a photo;
      // everything else must be unique, otherwise a card shows the wrong
      // dish.
      const Map<String, List<String>> allowed = <String, List<String>>{
        'coffee.jpg': <String>['p06', 'p08'],
        'dessert-cake.jpg': <String>['p07', 'p10'],
      };

      final byFile = <String, List<String>>{};
      for (final entry in expected.entries) {
        byFile.putIfAbsent(entry.value, () => <String>[]).add(entry.key);
      }

      for (final file in byFile.entries) {
        final ids = file.value;
        if (ids.length == 1) continue;

        expect(
          allowed[file.key],
          ids,
          reason: '${ids.join(', ')} share ${file.key} but are not the '
              'same food',
        );
      }
    });
  });
}
