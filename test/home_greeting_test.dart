// Guards the home screen's time-of-day greeting.
//
// The greeting is a real Figma element, so it must stay in the header —
// but it must be driven by an *injectable* clock, otherwise the golden and
// geometry tests would render "Chào buổi sáng" in the morning and
// "Chào buổi tối" in the evening, and the baseline would break every time
// the suite ran at another hour.
//
// These tests pin the clock and assert the three buckets (morning /
// afternoon / evening) plus the fact that the render no longer follows
// the wall clock.

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
  isBestSeller: true,
  restaurantName: 'Burger Queen',
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
  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      <Productsdb>[_burger];

  @override
  Future<List<Productsdb>> getAllProducts() async => <Productsdb>[_burger];

  @override
  Future<Productsdb?> getProduct(String id) async => _burger;

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async =>
      <Productsdb>[_burger];

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      <Productsdb>[_burger];

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> deleteProduct(String id) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}
}

/// Mounts the home screen with [clock] pinned to [hour] and returns the
/// greeting string that was rendered in the yellow header.
Future<String> _greetingAtHour(WidgetTester tester, int hour) async {
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
        child: ClientHomeScreen(
          clock: () => DateTime(2024, 1, 15, hour, 0, 0),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));

  final greeting = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .firstWhere(
        (s) =>
            s == 'Chào buổi sáng' ||
            s == 'Chào buổi chiều' ||
            s == 'Chào buổi tối',
        orElse: () => '',
      );

  // The carousel runs a 3.6 s periodic timer; unmount so the binding does
  // not complain about pending timers on teardown.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  return greeting;
}

void main() {
  setUpAll(loadAppFonts);

  group('home greeting', () {
    testWidgets('morning bucket covers hours before noon', (
      WidgetTester tester,
    ) async {
      expect(await _greetingAtHour(tester, 0), 'Chào buổi sáng');
      expect(await _greetingAtHour(tester, 11), 'Chào buổi sáng');
    });

    testWidgets('afternoon bucket covers noon up to 18:00', (
      WidgetTester tester,
    ) async {
      expect(await _greetingAtHour(tester, 12), 'Chào buổi chiều');
      expect(await _greetingAtHour(tester, 17), 'Chào buổi chiều');
    });

    testWidgets('evening bucket covers 18:00 onwards', (
      WidgetTester tester,
    ) async {
      expect(await _greetingAtHour(tester, 18), 'Chào buổi tối');
      expect(await _greetingAtHour(tester, 23), 'Chào buổi tối');
    });

    testWidgets('the pinned clock wins over the wall clock', (
      WidgetTester tester,
    ) async {
      // Whatever the machine clock reads, the screen must render the
      // greeting of the *injected* clock, not of the wall clock.
      expect(await _greetingAtHour(tester, 9), 'Chào buổi sáng');
      expect(await _greetingAtHour(tester, 21), 'Chào buổi tối');
    });

    test('the shared test clock is fixed', () {
      expect(fixedHomeNow(), DateTime(2024, 1, 15, 9, 0, 0));
      expect(fixedHomeClock(), fixedHomeNow());
    });
  });
}
