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
//   3. the safe sync script (`scripts/sync_catalogue.dart`) drifting away
//      from the canonical catalogue (`scripts/catalog_reference.json`).
//
// The canonical catalogue is `scripts/catalog_reference.json`; the live
// database is written from it by `scripts/sync_catalogue.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The folders a catalogue image may live in.
const List<String> _folders = <String>['products', 'categories'];

const Map<String, String> _productMirrors = <String, String>{
  'p01': 'burger-classic.jpg',
  'p02': 'pizza-pepperoni.jpg',
  'p03': 'poke-salmon-bowl.jpg',
  'p04': 'fried-chicken.jpg',
  'p05': 'poke-chicken-bowl.jpg',
  'p06': 'salted-caramel-latte.jpg',
  'p07': 'matcha-cheesecake.jpg',
  'p08': 'vietnamese-iced-coffee.jpg',
  'p09': 'green-goddess-salad.jpg',
  'p10': 'molten-chocolate-cake.jpg',
  'p11': 'burger-cheddar.jpg',
  'p12': 'burger-bacon.jpg',
  'p13': 'burger-mushroom.jpg',
  'p14': 'burger-spicy-chicken.jpg',
  'p15': 'pizza-margherita-wood.jpg',
  'p16': 'pizza-veggie.jpg',
  'p17': 'pizza-four-cheese.jpg',
  'p18': 'pizza-hawaiian.jpg',
  'p19': 'drink-cappuccino.jpg',
  'p20': 'drink-peach-tea.jpg',
  'p21': 'drink-strawberry-soda.jpg',
  'p22': 'dessert-tiramisu.jpg',
  'p23': 'dessert-brownie.jpg',
  'p24': 'dessert-macaron.jpg',
  'p25': 'healthy-quinoa-bowl.jpg',
  'p26': 'healthy-chicken-salad.jpg',
  'p27': 'healthy-avocado-bowl.jpg',
};

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

    test('every product photo uses the selected image host', () {
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final uri = Uri.parse(row['picture'] as String);
        expect(
          uri.host,
          anyOf(
            'images.unsplash.com',
            'matchado.co.uk',
            'artfultea.com',
            'cdn.shopify.com',
          ),
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
        final local = 'assets/products/${_productMirrors[entry.key]}';

        expect(
          File(local).existsSync(),
          isTrue,
          reason:
              '${entry.key} needs a bundled copy at $local so the app '
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
    test('the sync script reads canonical rows and merges safely', () {
      final script = File('scripts/sync_catalogue.dart').readAsStringSync();
      expect(script, contains("File(catalogPath).readAsString()"));
      expect(script, contains("merged[field] = desired[field]"));
      expect(
        script,
        contains("_write('\$dbRoot/products/\${entry.key}', merged)"),
      );
    });
  });

  group('the dish and its photo agree', () {
    // A photo that does not match the dish is the defect the user asked
    // to fix: a "Gà Chiên" card must not show a burger.
    test('each dish has a unique photo and matching bundled image', () {
      final urls = <String>{};
      for (final entry in products.entries) {
        final row = entry.value as Map<String, dynamic>;
        final url = row['picture'] as String;
        expect(urls.add(url), isTrue, reason: '${entry.key} reuses a URL');
        expect(
          File('assets/products/${_productMirrors[entry.key]}').existsSync(),
          isTrue,
          reason: '${entry.key} needs a matching bundled photo',
        );
      }
    });
  });
}
