// Golden harness for the client home screen.
//
// Renders ClientHomeScreen at the UI kit's native logical size and writes
// build/home_golden.png, which is then diffed against
// `3 - A - Home Page.png` to score the visual match.
//
// Fake services mirror test/products_bloc_test.dart so no Firebase is needed.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/home_clock.dart';
import 'helpers/load_fonts.dart';

const List<Category> _categories = <Category>[
  Category(id: '1', category: 'Burger', icon: 'burger', picture: '', color: 0xFFE95322),
  Category(id: '2', category: 'Pizza', icon: 'pizza', picture: '', color: 0xFFE95322),
  Category(id: '3', category: 'Drinks', icon: 'drink', picture: '', color: 0xFFE95322),
  Category(id: '4', category: 'Dessert', icon: 'dessert', picture: '', color: 0xFFE95322),
  Category(id: '5', category: 'Asian', icon: 'asian', picture: '', color: 0xFFE95322),
];

const Productsdb _burger = Productsdb(
  id: 'p1',
  nameProduct: 'Big Burger',
  description: 'Double cheese',
  price: 18.99,
  status: 1,
  picture: '',
  category: 'Burger',
  categoryId: '1',
  rating: 4.8,
  ratingCount: 120,
  sold: 320,
  isRecommended: true,
  isBestSeller: true,
  restaurantName: 'Burger Queen',
  oldPrice: 24.99,
);

const Productsdb _pepsi = Productsdb(
  id: 'p2',
  nameProduct: 'Pepsi',
  description: 'Cold drink',
  price: 4.99,
  status: 1,
  picture: '',
  category: 'Drinks',
  categoryId: '3',
  rating: 4.6,
  ratingCount: 86,
  sold: 540,
  isRecommended: true,
  isBestSeller: true,
  restaurantName: 'Soda Shop',
  oldPrice: 6.99,
);

const Productsdb _pizza = Productsdb(
  id: 'p3',
  nameProduct: 'Margherita',
  description: 'Tomato and basil',
  price: 12.50,
  status: 1,
  picture: '',
  category: 'Pizza',
  categoryId: '2',
  rating: 4.7,
  ratingCount: 64,
  sold: 210,
  isBestSeller: true,
  restaurantName: 'Pizza House',
  oldPrice: 15.90,
);

const Productsdb _sushi = Productsdb(
  id: 'p4',
  nameProduct: 'Salmon Roll',
  description: 'Fresh salmon',
  price: 15.00,
  status: 1,
  picture: '',
  category: 'Asian',
  categoryId: '5',
  rating: 4.9,
  ratingCount: 41,
  sold: 180,
  isBestSeller: true,
  restaurantName: 'Tokyo Bento',
  oldPrice: 18.40,
);

const Productsdb _pasta = Productsdb(
  id: 'p5',
  nameProduct: 'Creamy Pasta',
  description: 'Alfredo sauce',
  price: 11.75,
  status: 1,
  picture: '',
  category: 'Meal',
  categoryId: '2',
  rating: 4.5,
  ratingCount: 92,
  sold: 260,
  isBestSeller: true,
  isRecommended: true,
  restaurantName: 'Casa Pasta',
  oldPrice: 14.25,
);

const Productsdb _salad = Productsdb(
  id: 'p6',
  nameProduct: 'Garden Salad',
  description: 'Fresh greens',
  price: 8.40,
  status: 1,
  picture: '',
  category: 'Vegan',
  categoryId: '5',
  rating: 4.4,
  ratingCount: 57,
  sold: 143,
  isBestSeller: true,
  isRecommended: true,
  restaurantName: 'Green Bowl',
  oldPrice: 10.00,
);

const Productsdb _cake = Productsdb(
  id: 'p7',
  nameProduct: 'Cheesecake',
  description: 'Berry topping',
  price: 6.95,
  status: 1,
  picture: '',
  category: 'Dessert',
  categoryId: '4',
  rating: 4.8,
  ratingCount: 133,
  sold: 305,
  isBestSeller: true,
  isRecommended: true,
  restaurantName: 'Sweet Corner',
  oldPrice: 8.50,
);

const Productsdb _juice = Productsdb(
  id: 'p8',
  nameProduct: 'Fresh Juice',
  description: 'Orange & mint',
  price: 5.25,
  status: 1,
  picture: '',
  category: 'Drinks',
  categoryId: '3',
  rating: 4.3,
  ratingCount: 74,
  sold: 198,
  isBestSeller: true,
  isRecommended: true,
  restaurantName: 'Soda Shop',
  oldPrice: 6.75,
);

class _FakeCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories() async => _categories;

  @override
  Future<void> addCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}
}

class _FakeProductsService implements ProductsService {
  static const List<Productsdb> _all = <Productsdb>[
    _burger,
    _pepsi,
    _pizza,
    _sushi,
    _pasta,
    _salad,
    _cake,
    _juice,
  ];

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

void main() {
  setUpAll(bootstrapGolden);

  testWidgets('home screen matches kit layout', (WidgetTester tester) async {
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
    // Let the BLoC stream settle first.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Image decoding is genuinely asynchronous and will not complete inside
    // fake-async `pump()`.  Step out of the fake clock, let every bundled
    // image finish decoding, then re-enter to capture the frame.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ClientHomeScreen),
      matchesGoldenFile('home_golden.png'),
    );
  });
}