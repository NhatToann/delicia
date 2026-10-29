// Diagnostic: prints the actual laid-out Y/X of every key element so the
// numbers can be compared against the Figma kit's absolute coordinates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_clock.dart';
import 'helpers/load_fonts.dart';

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const List<Category> _categories = <Category>[
  Category(id: '1', category: 'Burger', icon: 'burger', picture: '', color: 0xFFE95322),
  Category(id: '2', category: 'Pizza', icon: 'pizza', picture: '', color: 0xFFE95322),
  Category(id: '3', category: 'Drinks', icon: 'drink', picture: '', color: 0xFFE95322),
  Category(id: '4', category: 'Dessert', icon: 'dessert', picture: '', color: 0xFFE95322),
  Category(id: '5', category: 'Asian', icon: 'asian', picture: '', color: 0xFFE95322),
];

const Productsdb _burger = Productsdb(
  id: 'p1', nameProduct: 'Big Burger', description: 'Double cheese',
  price: 18.99, status: 1, picture: '', category: 'Burger', categoryId: '1',
  rating: 4.8, ratingCount: 120, sold: 320, isRecommended: true,
  isBestSeller: true, restaurantName: 'Burger Queen', oldPrice: 24.99);

const Productsdb _pepsi = Productsdb(
  id: 'p2', nameProduct: 'Pepsi', description: 'Cold drink',
  price: 4.99, status: 1, picture: '', category: 'Drinks', categoryId: '3',
  rating: 4.6, ratingCount: 86, sold: 540, isRecommended: true,
  isBestSeller: true, restaurantName: 'Soda Shop', oldPrice: 6.99);

const Productsdb _pizza = Productsdb(
  id: 'p3', nameProduct: 'Margherita', description: 'Tomato and basil',
  price: 12.50, status: 1, picture: '', category: 'Pizza', categoryId: '2',
  rating: 4.7, ratingCount: 64, sold: 210, isBestSeller: true,
  restaurantName: 'Pizza House');

const Productsdb _sushi = Productsdb(
  id: 'p4', nameProduct: 'Salmon Roll', description: 'Fresh salmon',
  price: 15.00, status: 1, picture: '', category: 'Asian', categoryId: '5',
  rating: 4.9, ratingCount: 41, sold: 180, isBestSeller: true,
  restaurantName: 'Tokyo Bento');

class _FakeCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories() async => _categories;
  @override
  Future<void> addCategory(Category category) async {}
  @override
  Future<void> deleteCategory(String id) async {}
}

class _FakeProductsService implements ProductsService {
  static const List<Productsdb> _all = <Productsdb>[_burger, _pepsi, _pizza, _sushi];
  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async => _all.take(limit).toList();
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
  Future<List<ImageProductdb>> getProductImages(String productId) async => const <ImageProductdb>[];
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

void main() {
  setUpAll(loadAppFonts);

  testWidgets('positions', (WidgetTester tester) async {
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
          child: const ClientHomeScreen(
            // Pin the clock so the header greeting — and therefore the
            // golden image — never depends on the hour the suite runs at.
            clock: fixedHomeClock,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    debugPrint('MEDIAQUERY padding=${tester.view.padding} dpr=${tester.view.devicePixelRatio}');
    for (final t in <String>['Chào buổi sáng', 'Bán chạy', 'Gợi ý', 'Tìm kiếm']) {
      final f = find.text(t);
      if (f.evaluate().isEmpty) {
        debugPrint('MISSING: $t');
        continue;
      }
      final box = tester.getRect(f.first);
      debugPrint('TEXT "$t" -> x=${box.left} y=${box.top} w=${box.width} h=${box.height}');
    }
    // Report the golden image so we can diff rows. This fixture has a
    // four-product catalogue, so it needs its own golden; sharing
    // `home_golden.png` with the eight-product fixture made one of the two
    // always fail depending on which ran first.
    await expectLater(
      find.byType(ClientHomeScreen),
      matchesGoldenFile('home_positions_golden.png'),
    );
  });
}