// Guards the catalogue data contract.
//
// The live Firebase catalogue was wiped in October 2026: the migration
// script used the Realtime Database REST API's `PATCH`, which replaces the
// child nodes it touches *wholesale* instead of merging into them. Every
// product row came back with nothing but the translated fields, so
// `Productsdb.fromMap` fell back to `price = 0.0` and **every price in the
// app rendered as "0 ₫"**.
//
// These tests lock down the data contract that broke:
//
//   * a row without a `price` parses to 0 — and the app must be able to
//     *notice* that, so the bug is visible instead of silent;
//   * a row with a price parses to that price;
//   * the size options carry their own absolute prices;
//   * the canonical catalogue declares **complete** documents, so a seed
//     can never write a row that is missing a field the app reads.
//
// The canonical catalogue lives in `scripts/catalog_reference.json` — a
// tracked, human-readable reference that replaced the old Python seed and
// migration scripts (removed in October 2026). It is the reference for
// what a complete product row looks like.

import 'dart:convert';
import 'dart:io';

import 'package:delicia/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Productsdb — the price', () {
    test('a row with a price keeps it', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'price': 14.5,
        'status': 1,
      });

      expect(parsed.price, 14.5);
    });

    test('a row without a price parses to zero', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'status': 1,
      });

      expect(parsed.price, 0);
    });

    test('a row with a string price still parses', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'price': '14.50',
        'status': 1,
      });

      expect(parsed.price, 14.5);
    });

    test('the zero-price row is detectable, not silent', () {
      // This is the shape of the bug that wiped the catalogue: the row
      // parsed fine, it just carried no price at all. A screen that wants
      // to show "giá không xác định" instead of "0 ₫" needs this flag.
      final row = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'status': 1,
      });

      expect(row.price, 0);
      expect(row.hasPrice, isFalse);
    });

    test('a row with a price is flagged as priced', () {
      final row = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'price': 14.5,
        'status': 1,
      });

      expect(row.hasPrice, isTrue);
    });
  });

  group('Productsdb — the size options carry their own price', () {
    test('each option has its own absolute price', () {
      final row = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'price': 14.5,
        'status': 1,
        'options': <dynamic>[
          <dynamic, dynamic>{'id': 'opt1', 'label': 'Nhỏ', 'price': 14.5},
          <dynamic, dynamic>{'id': 'opt2', 'label': 'Vừa', 'price': 17.4},
        ],
      });

      expect(row.options.length, 2);
      expect(row.options.first.price, 14.5);
      expect(row.options.last.price, 17.4);
    });
  });

  group('the canonical catalogue', () {
    /// The tracked reference that replaced the old Python seed scripts.
    Map<String, dynamic> readCatalog() {
      final raw = File('scripts/catalog_reference.json').readAsStringSync();
      return jsonDecode(raw) as Map<String, dynamic>;
    }

    Map<String, dynamic> readProducts() =>
        readCatalog()['products'] as Map<String, dynamic>;

    Map<String, dynamic> readCategories() =>
        readCatalog()['categories'] as Map<String, dynamic>;

    test('every product declares every field the app reads', () {
      // Every field `Productsdb.fromMap` reads has to be in there, or a
      // fresh seed would leave a hole in the row.
      for (final field in <String>[
        'nameProduct',
        'nameProductEn',
        'description',
        'price',
        'category',
        'categoryId',
        'restaurantName',
        'rating',
        'ratingCount',
        'sold',
        'isRecommended',
        'isBestSeller',
        'picture',
        'status',
      ]) {
        for (final entry in readProducts().entries) {
          final row = entry.value as Map<String, dynamic>;
          expect(
            row.containsKey(field),
            isTrue,
            reason: '${entry.key} must declare "$field"',
          );
        }
      }
    });

    test('every product carries a usable price', () {
      // The regression that wiped the catalogue showed up as "0 ₫" on
      // every dish. A canonical row with no price would re-introduce it.
      for (final entry in readProducts().entries) {
        final row = entry.value as Map<String, dynamic>;
        final price = (row['price'] as num).toDouble();
        expect(price, greaterThan(0), reason: '${entry.key} must have a price');
      }
    });

    test('every product parses into a priced, active row', () {
      for (final entry in readProducts().entries) {
        final parsed = Productsdb.fromMap(entry.key, entry.value);
        expect(parsed.hasPrice, isTrue, reason: '${entry.key} must be priced');
        expect(parsed.isActive, isTrue, reason: '${entry.key} must be active');
        expect(parsed.nameProduct, isNotEmpty);
        expect(parsed.nameProductEn, isNotEmpty);
      }
    });

    test('every product points at a declared category', () {
      final categories = readCategories();
      for (final entry in readProducts().entries) {
        final row = entry.value as Map<String, dynamic>;
        expect(
          categories.containsKey(row['categoryId']),
          isTrue,
          reason: '${entry.key} points at an unknown category',
        );
      }
    });

    test('every category id is the stable ASCII slug', () {
      // `categoryId` is the database's index key. It must never change,
      // and it must never be a display name.
      for (final entry in readCategories().entries) {
        expect(entry.key, matches(RegExp(r'^[a-z0-9_]+$')));
      }
    });

    test('the size options are Vietnamese, not English', () {
      final options = readCatalog()['sizeOptions'] as List<dynamic>;
      expect(options, isNotEmpty);
      for (final option in options.cast<Map<String, dynamic>>()) {
        final label = option['label'] as String;
        // The Figma sample labels ("Personal", "Medium", …) are layout
        // samples, not catalogue data — the app is Vietnamese throughout.
        expect(label, isNot(contains('Personal')));
        expect(label, isNot(contains('Medium')));
        expect(label, isNot(contains('Jumbo')));
        expect(label, contains('phần'));
        expect(option['multiplier'], isA<num>());
        expect((option['multiplier'] as num).toDouble(), greaterThan(0));
      }
    });

    test('the size options build a complete, priced product row', () {
      final options = readCatalog()['sizeOptions'] as List<dynamic>;
      final base = 12.9;
      // The option price is the product's own price scaled by the
      // multiplier, rounded to two decimals — the same shape the old
      // Python seed script produced.
      final built = <Map<String, dynamic>>[
        for (final option in options.cast<Map<String, dynamic>>())
          <String, dynamic>{
            'id': option['id'],
            'label': option['label'],
            'price': ((base * (option['multiplier'] as num)) * 100)
                    .roundToDouble() /
                100,
          },
      ];

      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Burger Nấm Truffle Đặc Trưng',
        'price': base,
        'options': built,
      });

      expect(parsed.options.length, options.length);
      expect(parsed.options.first.id, 'opt1');
      expect(parsed.options.first.label, 'Nhỏ (4 phần)');
      expect(parsed.options.first.price, base);
      // Every option carries its own absolute price — never a delta.
      for (final option in parsed.options) {
        expect(option.price, greaterThan(0));
      }
    });
  });

  group('the l10n contract', () {
    test('every ARB key holds a non-empty string', () {
      // A cheap sanity check that the l10n contract holds: the ARB is
      // valid JSON and every value is a non-empty string.
      final arb = jsonDecode(
        File('lib/l10n/app_vi.arb').readAsStringSync(),
      ) as Map<String, dynamic>;

      for (final entry in arb.entries.where((e) => !e.key.startsWith('@'))) {
        expect(entry.value, isA<String>(), reason: '${entry.key} must be text');
        expect(
          (entry.value as String).trim(),
          isNotEmpty,
          reason: '${entry.key} must not be empty',
        );
      }
    });
  });
}
