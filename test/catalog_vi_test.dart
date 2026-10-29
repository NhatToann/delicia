// Guards the Vietnamese catalogue contract.
//
// The live Firebase catalogue was migrated to Vietnamese in October 2026.
// Three things must stay true after that migration:
//
//   1. the product model keeps the original English name so a customer who
//      types "burger" still finds the right dish;
//   2. the artwork a product falls back to is keyed off the stable
//      `categoryId`, not off the (now Vietnamese) display name;
//   3. a legacy row that still carries an English category name resolves
//      to the same artwork, so pre-migration rows keep rendering.

import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/presentation/helpers/category_assets.dart';
import 'package:flutter_test/flutter_test.dart';

Productsdb _product({
  String id = 'p01',
  String nameProduct = 'Burger Nấm Truffle Đặc Trưng',
  String nameProductEn = 'Signature Truffle Burger',
  String description = 'Thịt trộn Wagyu, cheddar lão hóa.',
  String category = 'Bánh Burger',
  String categoryId = 'cat_burger',
  String picture = '',
}) {
  return Productsdb(
    id: id,
    nameProduct: nameProduct,
    description: description,
    price: 12.9,
    status: 1,
    picture: picture,
    category: category,
    categoryId: categoryId,
    nameProductEn: nameProductEn,
  );
}

void main() {
  group('Productsdb.matchesQuery', () {
    test('an empty query matches everything', () {
      expect(_product().matchesQuery(''), isTrue);
      expect(_product().matchesQuery('   '), isTrue);
    });

    test('matches the Vietnamese name', () {
      expect(_product().matchesQuery('Burger'), isTrue);
      expect(_product().matchesQuery('truffle'), isTrue);
      expect(_product().matchesQuery('đặc trưng'), isTrue);
    });

    test('matches the English name kept for search', () {
      expect(_product().matchesQuery('signature'), isTrue);
      expect(_product().matchesQuery('TRUFFLE'), isTrue);
    });

    test('is accent-insensitive', () {
      expect(_product().matchesQuery('đặc'), isTrue);
      expect(_product().matchesQuery('đac'), isTrue);
    });

    test('matches the description', () {
      expect(_product().matchesQuery('wagyu'), isTrue);
      expect(_product().matchesQuery('cheddar'), isTrue);
    });

    test('rejects a query that matches nothing', () {
      expect(_product().matchesQuery('pizza'), isFalse);
      expect(_product().matchesQuery('xyzzy'), isFalse);
    });

    test('a row without an English name still matches its own copy', () {
      final row = _product(nameProductEn: '');
      expect(row.matchesQuery('burger'), isTrue);
      expect(row.matchesQuery('signature'), isFalse);
    });
  });

  group('CategoryAssets.photoFor', () {
    test('the row picture always wins', () {
      final row = _product(picture: 'assets/products/burger-classic.jpg');
      expect(CategoryAssets.photoFor(row), 'assets/products/burger-classic.jpg');
    });

    test('falls back to the category id', () {
      final row = _product(categoryId: 'cat_pizza');
      expect(
        CategoryAssets.photoFor(row),
        CategoryAssets.photoByCategoryId['cat_pizza'],
      );
    });

    test('the same category id resolves the same artwork', () {
      final burger = _product(category: 'Bánh Burger', categoryId: 'cat_burger');
      final renamed = _product(
        category: 'Burger Việt',
        categoryId: 'cat_burger',
      );
      expect(
        CategoryAssets.photoFor(burger),
        CategoryAssets.photoFor(renamed),
      );
    });

    test('a legacy English category name still resolves', () {
      final legacy = _product(category: 'Burger', categoryId: 'unknown-id');
      final vietnamese = _product(
        category: 'Bánh Burger',
        categoryId: 'unknown-id',
      );
      expect(
        CategoryAssets.photoFor(legacy),
        CategoryAssets.photoFor(vietnamese),
      );
      expect(
        CategoryAssets.photoFor(legacy),
        CategoryAssets.photoByName['burger'],
      );
    });

    test('an unknown category falls back to the deterministic pool', () {
      final row = _product(category: 'Không Rõ', categoryId: 'nope');
      expect(CategoryAssets.pool, contains(CategoryAssets.photoFor(row)));
    });
  });

  group('CategoryAssets.iconFor', () {
    test('keys off the category id', () {
      final category = Category(id: 'cat_drink', category: 'Đồ Uống');
      expect(CategoryAssets.iconFor(category), 'cat_drinks.svg');
    });

    test('falls back to the icon slug when the id is unknown', () {
      final category = Category(
        id: 'nope',
        category: 'Không Rõ',
        icon: 'pizza',
      );
      expect(CategoryAssets.iconFor(category), 'cat_meals.svg');
    });
  });

  group('CategoryAssets.normalize', () {
    test('strips Vietnamese diacritics', () {
      expect(CategoryAssets.normalize('Bánh Burger'), 'banh burger');
      expect(CategoryAssets.normalize('Tráng Miệng'), 'trang mieng');
      expect(CategoryAssets.normalize('Đồ Uống'), 'do uong');
      expect(CategoryAssets.normalize('Món Lành Mạnh'), 'mon lanh manh');
    });

    test('leaves plain ASCII untouched', () {
      expect(CategoryAssets.normalize('Pizza'), 'pizza');
    });
  });
}
