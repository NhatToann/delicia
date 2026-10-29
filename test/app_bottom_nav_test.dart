// UC-02 / UC-05 — The app-wide bottom navigation bar.
//
// The customer must never wonder whether the "Orders" tab means the same
// thing on the home screen and on the product-detail screen. Every client
// screen therefore renders the *same* widget — [AppBottomNav] — and taps
// the same destination go to the same route.
//
// This file guards that promise:
//   * every screen renders exactly one [AppBottomNav];
//   * the bar itself always has the same four destinations.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:delicia/presentation/client/orders/orders_screen.dart';
import 'package:delicia/presentation/client/product_detail/product_detail_screen.dart';
import 'package:delicia/presentation/client/search/search_for_category_screen.dart';
import 'package:delicia/presentation/components/app_bottom_nav.dart';
import 'package:delicia/presentation/components/app_nav_destination.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';
import 'helpers/home_clock.dart';

const _dish = Productsdb(
  id: 'p01',
  nameProduct: 'Pizza Gà Cay',
  description: 'Mô tả món ăn.',
  price: 15.00,
  status: 1,
  picture: 'assets/products/pizza-margherita.jpg',
  category: 'Pizza',
  categoryId: 'cat_pizza',
  rating: 4.7,
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
  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      <Productsdb>[_dish];

  @override
  Future<List<Productsdb>> getAllProducts() async => <Productsdb>[_dish];

  @override
  Future<Productsdb?> getProduct(String id) async => _dish;

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async => <Productsdb>[
    _dish,
  ];

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      <Productsdb>[_dish];

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}

/// The orders service is not exercised by this file — the orders screen
/// only needs *a* bloc to render.
class _FakeOrdersService implements OrdersService {
  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
  }) async => throw UnimplementedError();

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {}

  @override
  Future<OrderRecord?> getOrder(String id) async => null;

  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) =>
      const Stream<List<OrderRecord>>.empty();

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      const Stream<OrderRecord?>.empty();
}

void main() {
  group('AppBottomNav', () {
    testWidgets('renders the four destinations and the cart pill', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              cartCount: 3,
              onTap: (_) {},
              onTapCart: () {},
            ),
          ),
        ),
      );

      // Four destinations, one cart pill.
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.byIcon(Icons.shopping_bag_rounded), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides the cart pill when there is nothing to open', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              onTap: (_) {},
              showCart: false,
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shopping_bag_rounded), findsNothing);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
    });

    testWidgets('reads the cart badge from the bloc when it is not given', (
      WidgetTester tester,
    ) async {
      final cart = CartBloc();
      addTearDown(cart.close);
      cart.add(
        const OnAddProductToCartEvent(
          ProductCart(
            uidProduct: 'p01',
            imageProduct: '',
            nameProduct: 'Pizza',
            price: 10,
            quantity: 2,
          ),
        ),
      );
      await tester.pump();

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BlocProvider<CartBloc>.value(
            value: cart,
            child: Scaffold(
              body: const SizedBox.shrink(),
              bottomNavigationBar: AppBottomNav(
                currentIndex: 0,
                onTap: (_) {},
                onTapCart: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('2'), findsOneWidget);
    });
    testWidgets('survives a missing cart bloc', (WidgetTester tester) async {
      // A screen rendered in isolation must not crash on the badge.
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: const SizedBox.shrink(),
            bottomNavigationBar: AppBottomNav(
              currentIndex: 0,
              onTap: (_) {},
              onTapCart: () {},
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('AppNavDestination', () {
    test('the four destinations are stable ids', () {
      expect(AppNavDestination.home, 0);
      expect(AppNavDestination.discover, 1);
      expect(AppNavDestination.orders, 2);
      expect(AppNavDestination.tracking, 3);
      expect(AppNavDestination.count, 4);
    });
  });

  group('every client screen uses the same bar', () {
    testWidgets('the home screen renders it', (WidgetTester tester) async {
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
                  productsService: _FakeProductsService(),
                ),
              ),
              BlocProvider<CartBloc>.value(value: cart),
            ],
            child: const ClientHomeScreen(clock: fixedHomeClock),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('the search screen renders it', (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final products = ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(),
      );
      addTearDown(products.close);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: BlocProvider<ProductsBloc>.value(
            value: products,
            child: const SearchForCategoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('the product detail screen renders it', (
      WidgetTester tester,
    ) async {
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
                  productsService: _FakeProductsService(),
                ),
              ),
              BlocProvider<CartBloc>.value(value: cart),
            ],
            child: const ProductDetailScreen(productId: 'p01'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(AppBottomNav), findsOneWidget);
    });

    testWidgets('the orders screen renders it', (WidgetTester tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final orders = OrdersBloc(ordersService: _FakeOrdersService());
      addTearDown(orders.close);
      final auth = AuthBloc(authService: FakeAuthService());
      addTearDown(auth.close);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<OrdersBloc>.value(value: orders),
            ],
            child: const ClientOrdersView(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(AppBottomNav), findsOneWidget);
    });
  });
}
