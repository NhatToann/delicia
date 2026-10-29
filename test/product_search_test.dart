// UC-02 — ProductSearch engine tests.
//
// The search engine is pure text processing over rows the bloc already
// holds in memory, so it can be tested without Firebase and without
// pumping a widget. These tests pin down the three rules that matter:
//
//   1. every query token has to match (an "AND" search);
//   2. the English name still matches, because the catalogue is
//      Vietnamese but customers type what they remember;
//   3. results are ordered by relevance, not by database order.

import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/utils/product_search.dart';
import 'package:flutter_test/flutter_test.dart';

Productsdb _p(
  String id,
  String name, {
  String nameEn = '',
  String description = '',
  String category = '',
  String categoryId = 'cat_burger',
  int status = 1,
}) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: description,
    price: 10,
    status: status,
    picture: '',
    category: category,
    categoryId: categoryId,
    nameProductEn: nameEn,
  );
}

List<Productsdb> get _catalogue => [
      _p(
        'p01',
        'Burger Nấm Truffle Đặc Trưng',
        nameEn: 'Signature Truffle Burger',
        description: 'Thịt trộn Wagyu, cheddar lão hóa.',
        category: 'Bánh Burger',
        categoryId: 'cat_burger',
      ),
      _p(
        'p02',
        'Pizza Gà Cay',
        nameEn: 'Spicy Chicken Pizza',
        description: 'Đế sourdough, phô mai mozzarella.',
        category: 'Pizza',
        categoryId: 'cat_pizza',
      ),
      _p(
        'p03',
        'Bowl Poke Cá Hồi Miso',
        nameEn: 'Miso Salmon Poke Bowl',
        description: 'Cá hồi, bơ, sốt miso.',
        category: 'Món Lành Mạnh',
        categoryId: 'cat_healthy',
      ),
      _p(
        'p04',
        'Gà Chiên Giòn',
        nameEn: 'Crispy Fried Chicken',
        description: 'Gà chiên xù dầu.',
        category: 'Bánh Burger',
        categoryId: 'cat_burger',
      ),
      _p(
        'p06',
        'Latte Caramel Muối',
        nameEn: 'Salted Caramel Latte',
        description: 'Cà phê espresso, caramel muối.',
        category: 'Đồ Uống',
        categoryId: 'cat_drink',
      ),
    ];

void main() {
  group('ProductSearch — matching', () {
    test('an empty query keeps every product, in catalogue order', () {
      final results = ProductSearch.filter(_catalogue, '');
      expect(results.length, _catalogue.length);
      expect(results.map((p) => p.id).toList(), ['p01', 'p02', 'p03', 'p04', 'p06']);
    });

    test('a whitespace-only query keeps every product', () {
      expect(ProductSearch.filter(_catalogue, '   ').length, _catalogue.length);
    });

    test('matches the Vietnamese name', () {
      final results = ProductSearch.filter(_catalogue, 'truffle');
      expect(results.map((p) => p.id), contains('p01'));
    });

    test('matches the English name kept for search', () {
      final results = ProductSearch.filter(_catalogue, 'spicy');
      expect(results.map((p) => p.id), contains('p02'));
    });

    test('matches the description', () {
      final results = ProductSearch.filter(_catalogue, 'mozzarella');
      expect(results.map((p) => p.id), contains('p02'));
    });

    test('matches the category name', () {
      final results = ProductSearch.filter(_catalogue, 'latte');
      expect(results.map((p) => p.id), contains('p06'));
      final byCategory = ProductSearch.filter(_catalogue, 'do uong');
      expect(byCategory.map((p) => p.id), contains('p06'));
    });

    test('is case-insensitive', () {
      final lower = ProductSearch.filter(_catalogue, 'truffle');
      final upper = ProductSearch.filter(_catalogue, 'TRUFFLE');
      expect(upper.map((p) => p.id), lower.map((p) => p.id));
    });

    test('is accent-insensitive', () {
      expect(
        ProductSearch.filter(_catalogue, 'dac trung').map((p) => p.id),
        contains('p01'),
      );
      expect(
        ProductSearch.filter(_catalogue, 'trang mieng'),
        isEmpty,
      );
    });

    test('every token has to match — an AND search', () {
      // "truffle" alone matches p01; "pizza" alone matches p02. Together
      // they match nothing, which is what a customer expects.
      final results = ProductSearch.filter(_catalogue, 'truffle pizza');
      expect(results, isEmpty);
    });

    test('a multi-token query still matches when both tokens are present', () {
      final results = ProductSearch.filter(_catalogue, 'truffle burger');
      expect(results.map((p) => p.id), contains('p01'));
    });

    test('a query matching nothing returns an empty list', () {
      expect(ProductSearch.filter(_catalogue, 'zzzzzz'), isEmpty);
    });

    test('punctuation acts as a token separator', () {
      final results = ProductSearch.filter(_catalogue, 'pizza, gà');
      expect(results.map((p) => p.id), contains('p02'));
    });
  });

  group('ProductSearch — ranking', () {
    test('a name hit outranks a description hit', () {
      // "burger" is in p01's *name* and in p04's name too, but p01 also
      // carries it in the English name. Both are name hits, so we compare
      // against a product that only mentions it in the description.
      final withDescriptionHit = _catalogue + [
        _p(
          'p99',
          'Món Nhà Làm',
          description: 'Món này có burger kèm.',
          category: 'Khác',
          categoryId: 'cat_other',
        ),
      ];
      final results = ProductSearch.filter(withDescriptionHit, 'burger');
      final ids = results.map((p) => p.id).toList();
      expect(ids.indexOf('p01'), lessThan(ids.indexOf('p99')));
    });

    test('an English name hit outranks a description hit', () {
      final results = ProductSearch.filter(_catalogue, 'miso');
      // p03 matches "miso" in its English name, its Vietnamese name and
      // its description — it must be found.
      expect(results.map((p) => p.id), contains('p03'));
    });

    test('the catalogue order is kept for equally good matches', () {
      final results = ProductSearch.filter(_catalogue, 'burger');
      final ids = results.map((p) => p.id).toList();
      // p01 comes before p04 in the catalogue and both are name hits.
      expect(ids.indexOf('p01'), lessThan(ids.indexOf('p04')));
    });

    test('a shorter name wins a tie', () {
      final results = ProductSearch.filter(_catalogue, 'burger');
      expect(results.first.id, 'p01');
    });
  });

  group('ProductSearch — sold-out rows', () {
    test('a sold-out row is not offered', () {
      final catalogue = [
        _p('p01', 'Burger Nấm'),
        _p('p02', 'Burger Hết Hàng', status: 0),
      ];
      final results = ProductSearch.filter(catalogue, '');
      expect(results.map((p) => p.id), ['p01']);
    });

    test('a sold-out row is not offered even when it matches the query', () {
      final catalogue = [
        _p('p01', 'Burger Nấm'),
        _p('p02', 'Burger Hết Hàng', status: 0),
      ];
      final results = ProductSearch.filter(catalogue, 'burger');
      expect(results.map((p) => p.id), ['p01']);
    });
  });

  group('ProductSearch — category filter', () {    test('restricts the results to one category', () {
      final results = ProductSearch.filter(
        _catalogue,
        '',
        categoryId: 'cat_burger',
      );
      expect(results.map((p) => p.id).toList(), ['p01', 'p04']);
    });

    test('an empty category id means "no filter"', () {
      final results = ProductSearch.filter(_catalogue, '', categoryId: '');
      expect(results.length, _catalogue.length);
    });

    test('a query plus a category only returns matching rows of that category',
        () {
      final results = ProductSearch.filter(
        _catalogue,
        'burger',
        categoryId: 'cat_burger',
      );
      expect(results.map((p) => p.id).toList(), ['p01', 'p04']);
    });

    test('a query plus a category excludes other categories', () {
      // "pizza" is a category name, but the customer filtered to burgers.
      final results = ProductSearch.filter(
        _catalogue,
        'pizza',
        categoryId: 'cat_burger',
      );
      expect(results, isEmpty);
    });
  });

  group('ProductSearch — hits', () {
    test('a hit reports the tokens it matched', () {
      final hits = ProductSearch.rank(_catalogue, 'truffle burger');
      expect(hits, isNotEmpty);
      expect(hits.first.matchedTokens, containsAll(['truffle', 'burger']));
    });

    test('a hit carries the product and a positive score', () {
      final hits = ProductSearch.rank(_catalogue, 'truffle');
      expect(hits, isNotEmpty);
      expect(hits.first.product.id, 'p01');
      expect(hits.first.score, greaterThan(0));
    });

    test('an empty query produces hits with a zero score', () {
      final hits = ProductSearch.rank(_catalogue, '');
      expect(hits.length, _catalogue.length);
      expect(hits.every((h) => h.score == 0), isTrue);
    });
  });
}
