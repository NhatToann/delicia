// UC-02 — Product detail: discount badge + quantity source of truth.
//
// Figma node `192:1216` draws a starburst badge over the product photo
// reading "-30%". The *number* must come from the product row (the
// `oldPrice` / `price` pair), never from a constant in the widget — so a
// dish that is not on offer shows no badge at all.
//
// The stepper on the same screen is bound to `CartBloc.selectedQuantity`,
// so the number the customer sees, the number the CTA multiplies the price
// by and the number that lands in the cart line can never disagree.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/product_detail/product_detail_screen.dart';
import 'package:delicia/presentation/client/product_detail/widgets/discount_badge.dart';
import 'package:delicia/presentation/components/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// A product that is 25 % off: 20.00 → 15.00.
const _discounted = Productsdb(
  id: 'p01',
  nameProduct: 'Pizza Gà Cay',
  description: 'Mô tả món ăn.',
  price: 15.00,
  oldPrice: 20.00,
  status: 1,
  picture: 'assets/products/pizza-margherita.jpg',
  category: 'Pizza',
  categoryId: 'cat_pizza',
  rating: 4.7,
);

/// A product that is not on offer.
const _plain = Productsdb(
  id: 'p02',
  nameProduct: 'Cà Phê Đá Việt',
  description: 'Mô tả món ăn.',
  price: 15.00,
  status: 1,
  picture: 'assets/products/salted-caramel-latte.jpg',
  category: 'Đồ Uống',
  categoryId: 'cat_drink',
);

class _FakeCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories() async => const <Category>[];

  @override
  Future<void> addCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}
}

class _FakeProductsService implements ProductsService {
  _FakeProductsService(this.product);

  final Productsdb product;

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      <Productsdb>[product];

  @override
  Future<List<Productsdb>> getAllProducts() async => <Productsdb>[product];

  @override
  Future<Productsdb?> getProduct(String id) async => product;

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async => <Productsdb>[
    product,
  ];

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      <Productsdb>[product];

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}

/// Pumps the detail screen with a fake catalogue.
Future<CartBloc> _pump(
  WidgetTester tester, {
  Productsdb product = _discounted,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cart = CartBloc();
  addTearDown(cart.close);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ProductsBloc>(
            create: (_) => ProductsBloc(
              categoryService: _FakeCategoryService(),
              productsService: _FakeProductsService(product),
            ),
          ),
          BlocProvider<CartBloc>.value(value: cart),
        ],
        child: ProductDetailScreen(productId: product.id),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return cart;
}

void main() {
  group('Productsdb.discountPercent', () {
    test('is derived from oldPrice and price', () {
      expect(_discounted.discountPercent, 25);
    });

    test('is null when the dish is not on offer', () {
      expect(_plain.discountPercent, isNull);
    });

    test('is null when the "was" price is not higher', () {
      const row = Productsdb(
        id: 'p03',
        nameProduct: 'Món',
        description: '',
        price: 20.00,
        oldPrice: 15.00,
        status: 1,
        picture: '',
        category: 'Pizza',
        categoryId: 'cat_pizza',
      );
      expect(row.discountPercent, isNull);
    });

    test('is null when either price is zero', () {
      const row = Productsdb(
        id: 'p04',
        nameProduct: 'Món',
        description: '',
        price: 0,
        oldPrice: 20.00,
        status: 1,
        picture: '',
        category: 'Pizza',
        categoryId: 'cat_pizza',
      );
      expect(row.discountPercent, isNull);
    });

    test('rounds to a whole percent', () {
      const row = Productsdb(
        id: 'p05',
        nameProduct: 'Món',
        description: '',
        price: 7.00,
        oldPrice: 9.99,
        status: 1,
        picture: '',
        category: 'Pizza',
        categoryId: 'cat_pizza',
      );
      // (9.99 - 7.00) / 9.99 = 29.9… % → 30 %
      expect(row.discountPercent, 30);
    });
  });

  group('ProductDetailScreen — the discount badge', () {
    testWidgets('shows the badge with the derived percentage', (tester) async {
      await _pump(tester);

      expect(find.byType(DiscountBadge), findsOneWidget);
      expect(find.text('-25%'), findsOneWidget);
    });

    testWidgets('shows no badge when the dish is not on offer', (tester) async {
      await _pump(tester, product: _plain);

      expect(find.byType(DiscountBadge), findsNothing);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('the badge never renders the Figma sample "-30%"', (
      tester,
    ) async {
      await _pump(tester);

      // "-30%" is the layout sample in the Figma frame. The real number
      // comes from the row, so a 25 % dish must not show 30 %.
      expect(find.text('-30%'), findsNothing);
    });
  });

  group('ProductDetailScreen — the quantity stepper', () {
    testWidgets('the stepper writes to the cart bloc', (tester) async {
      final cart = await _pump(tester);

      expect(cart.state.selectedQuantity, 1);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(cart.state.selectedQuantity, 3);
    });

    testWidgets('the quantity shown matches the bloc', (tester) async {
      final cart = await _pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      expect(find.text('2'), findsWidgets);
      expect(cart.state.selectedQuantity, 2);
    });

    testWidgets('the cart line carries the quantity the customer picked', (
      tester,
    ) async {
      final cart = await _pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      await tester.tap(find.text('Thêm vào giỏ hàng'));
      await tester.pump();

      expect(cart.state.products!.first.quantity, 3);
    });

    testWidgets('the stepper starts at 1 for every dish', (tester) async {
      final cart = await _pump(tester);

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      expect(cart.state.selectedQuantity, 2);

      // A different dish resets the stepper — the previous dish's quantity
      // must not leak into the next one.
      final second = await _pump(tester, product: _plain);
      expect(second.state.selectedQuantity, 1);
    });
  });

  group('ProductDetailScreen — the Figma footer', () {
    testWidgets('the app-wide navigation bar is rendered', (tester) async {
      await _pump(tester);

      // The product detail screen uses the same bar as every other screen
      // — the Figma-illustrative orange bar was replaced by the real one.
      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('no overflow with the footer in place', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
