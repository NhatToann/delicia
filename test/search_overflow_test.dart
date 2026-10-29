// Regression tests for the search screen overflow.
//
// Before the fix, every `ProductCard` painted a yellow
// "BOTTOM OVERFLOWED BY 19 px" stripe: the grid's `childAspectRatio: 0.68`
// left `Expanded(flex: 3)` with ~68 px of usable height, while the card
// demanded ~78 px (14 px padding * 2 + a 15 px two-line title + an 8 px
// gap + a 34 px price row).
//
// These tests pin the card's intrinsic height to what the grid actually
// reserves, at every common phone size and text scale.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/search/search_for_category_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

Productsdb _p(
  String id,
  String name,
  String category,
  double price, {
  double rating = 4.8,
}) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: name,
    price: price,
    status: 1,
    picture: '',
    category: category,
    categoryId: '1',
    rating: rating,
    ratingCount: 120,
    sold: 320,
    isRecommended: true,
    isBestSeller: true,
    restaurantName: 'Test Kitchen',
    oldPrice: 20.00,
  );
}

const List<Category> _categories = <Category>[
  Category(id: '1', category: 'Burger', icon: 'burger', picture: ''),
  Category(id: '2', category: 'Pizza', icon: 'pizza', picture: ''),
];

// A deliberately nasty catalogue: long names, no rating, long prices.
final List<Productsdb> _all = <Productsdb>[
  _p('p1', 'Big Burger', 'Burger', 18.99),
  _p('p2', 'Margherita', 'Pizza', 12.50),
  _p('p3', 'Salmon Roll', 'Vegan', 15.00, rating: 0),
  _p(
    'p4',
    'Creamy Carbonara Pasta With Aged Parmesan',
    'Meal',
    123456.78,
  ),
  _p('p5', 'Garden Salad', 'Vegan', 8.40),
  _p('p6', 'Cheesecake', 'Dessert', 6.95),
];

class _FakeCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories() async => _categories;

  @override
  Future<void> addCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}
}

class _FakeProductsService implements ProductsService {
  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      _all.take(limit).toList();

  @override
  Future<List<Productsdb>> getAllProducts() async => _all;

  @override
  Future<Productsdb?> getProduct(String id) async {
    for (final p in _all) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async => _all;

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      _all.where((p) => p.categoryId == categoryId).toList();

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}
}

Future<void> _pumpSearch(
  WidgetTester tester,
  Size size, {
  double textScale = 1.0,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MultiBlocProvider(
          providers: <BlocProvider<dynamic>>[
            BlocProvider<ProductsBloc>(
              create: (_) => ProductsBloc(
                categoryService: _FakeCategoryService(),
                productsService: _FakeProductsService(),
              ),
            ),
            BlocProvider<CartBloc>(create: (_) => CartBloc()),
          ],
          child: const SearchForCategoryScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('search screen overflow', () {
    testWidgets('no overflow on any common phone size', (
      WidgetTester tester,
    ) async {
      const sizes = <Size>[
        Size(320, 568),
        Size(360, 640),
        Size(393, 852),
        Size(412, 915),
        Size(430, 932),
      ];
      for (final s in sizes) {
        await _pumpSearch(tester, s);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow on ${s.width.toInt()}x${s.height.toInt()}',
        );
      }
    });

    testWidgets('no overflow at 1.3x and 1.8x text scale', (
      WidgetTester tester,
    ) async {
      for (final scale in <double>[1.3, 1.8]) {
        await _pumpSearch(tester, const Size(393, 852), textScale: scale);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow at text scale $scale',
        );
      }
    });

    testWidgets('no overflow with the soft keyboard open', (
      WidgetTester tester,
    ) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ProductsBloc>(
                create: (_) => ProductsBloc(
                  categoryService: _FakeCategoryService(),
                  productsService: _FakeProductsService(),
                ),
              ),
              BlocProvider<CartBloc>(create: (_) => CartBloc()),
            ],
            child: const SearchForCategoryScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Simulate a ~320 px keyboard inset.
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(() => tester.view.resetViewInsets());
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow with a 320 px keyboard inset',
      );
    });

    testWidgets('every product card renders inside its grid cell', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, const Size(393, 852));
      // The catalogue is loaded, so all six cards must be present.
      expect(find.text('Big Burger'), findsWidgets);
      expect(find.text('Garden Salad'), findsWidgets);
    });

    testWidgets('typing a query shows the counter and highlights the match', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, const Size(393, 852));

      await tester.enterText(find.byType(TextFormField), 'burger');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      // No overflow once the result counter and the highlight are in play.
      expect(tester.takeException(), isNull);

      // The counter tells the customer how many dishes matched.
      expect(find.textContaining('món ăn'), findsWidgets);

      // "Big Burger" is the only name containing "burger".
      expect(find.text('Big Burger'), findsOneWidget);
    });

    testWidgets('no overflow when a query matches nothing', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, const Size(393, 852));

      await tester.enterText(find.byType(TextFormField), 'zzzzz');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The empty state explains that nothing matched.
      expect(find.byIcon(Icons.search_off), findsOneWidget);
    });

    testWidgets('no overflow with a query at 1.8x text scale', (
      WidgetTester tester,
    ) async {
      await _pumpSearch(tester, const Size(393, 852), textScale: 1.8);

      await tester.enterText(find.byType(TextFormField), 'burger');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}