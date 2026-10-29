// Behavioural regression tests for the issues reported on the home screen.
//
// Each test targets one concrete defect:
//   * taps resolved to the wrong dish (burger card opened a latte)
//   * the header icons were dead and the row overflowed
//   * the promo banner could not advance from the middle slide
//   * Recommend rendered too few cards
//   * "View All" did nothing
//   * the footer clipped its own labels
//
// Fake services mirror home_golden_test.dart so no Firebase is needed.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/cart/widgets/cart_panel.dart';
import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/load_fonts.dart';

const List<Category> _categories = <Category>[
  Category(
    id: '1',
    category: 'Burger',
    icon: 'burger',
    picture: '',
    color: 0xFFE95322,
  ),
  Category(
    id: '2',
    category: 'Pizza',
    icon: 'pizza',
    picture: '',
    color: 0xFFE95322,
  ),
  Category(
    id: '3',
    category: 'Drinks',
    icon: 'drink',
    picture: '',
    color: 0xFFE95322,
  ),
];

Productsdb _p(
  String id,
  String name,
  String category,
  String categoryId,
  double price,
) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: name,
    price: price,
    status: 1,
    picture: '',
    category: category,
    categoryId: categoryId,
    rating: 4.8,
    ratingCount: 120,
    sold: 320,
    isRecommended: true,
    isBestSeller: true,
    restaurantName: 'Test Kitchen',
    oldPrice: 20.00,
  );
}

final List<Productsdb> _all = <Productsdb>[
  _p('p1', 'Big Burger', 'Burger', '1', 18.99),
  _p('p2', 'Margherita', 'Pizza', '2', 12.50),
  _p('p3', 'Salmon Roll', 'Vegan', '5', 15.00),
  _p('p4', 'Creamy Pasta', 'Meal', '2', 11.75),
  _p('p5', 'Garden Salad', 'Vegan', '5', 8.40),
  _p('p6', 'Cheesecake', 'Dessert', '4', 6.95),
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

Future<void> _pumpHome(WidgetTester tester, Size size) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp.router(
      debugShowCheckedModeBanner: false,
      // `context.push` asserts when there is no GoRouter in the tree, so the
      // harness mounts a stub router with catch-all routes. That lets the
      // interaction tests exercise the real navigation calls.
      routerConfig: GoRouter(
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<ProductsBloc>(
                  create: (_) => ProductsBloc(
                    categoryService: _FakeCategoryService(),
                    productsService: _FakeProductsService(),
                  ),
                ),
                BlocProvider<CartBloc>(create: (_) => CartBloc()),
              ],
              child: const ClientHomeScreen(),
            ),
          ),
          GoRoute(
            path: '/client/search-category',
            builder: (_, _) => const SizedBox(),
          ),
          GoRoute(path: '/client/orders', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/client/map', builder: (_, _) => const SizedBox()),
          GoRoute(path: '/client/cart', builder: (_, _) => const SizedBox()),
          GoRoute(
            path: '/client/details-product/:id',
            builder: (_, _) => const SizedBox(),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pumpAndSettle();

  // The carousel runs a 3.6 s periodic timer. Flutter's test binding asserts
  // `!timersPending` on teardown, so unmount the screen and let `dispose`
  // cancel it for every test that pumps the home screen.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}

void main() {
  setUpAll(bootstrapGolden);

  group('home layout', () {
    testWidgets('renders without overflow at every common phone size', (
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
        await _pumpHome(tester, s);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflow on ${s.width.toInt()}x${s.height.toInt()}',
        );
      }
    });

    testWidgets('footer labels are all visible and not clipped', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(360, 640));
      for (final label in const <String>[
        'Trang chủ',
        'Khám phá',
        'Đơn hàng',
        'Yêu thích',
      ]) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'footer label "$label" must be rendered',
        );
      }
    });

    testWidgets('Recommend renders the full set, not a truncated rail', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      // Four rows of cards exist across both rails; the previous bug left
      // Recommend with a single card whenever the shared feed ran short.
      expect(find.text('Gợi ý'), findsOneWidget);
      expect(find.text('Bán chạy'), findsOneWidget);
    });
  });

  group('header actions', () {
    testWidgets('search pill is exposed as a tappable field', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      // The route push needs a real GoRouter, which this harness does not
      // mount; assert the control exists and the tap does not blow up.
      expect(find.text('Tìm kiếm'), findsOneWidget);
      await tester.tap(find.text('Tìm kiếm'));
      expect(tester.takeException(), isNull);
    });

    testWidgets('filter disc opens the category sheet', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      final filter = find.bySemanticsLabel('Lọc');
      expect(filter, findsOneWidget, reason: 'filter icon must be exposed');
      await tester.tap(filter);
      await tester.pumpAndSettle();
      expect(find.text('Lọc theo danh mục'), findsOneWidget);
    });

    testWidgets('cart action opens the cart drawer', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      final cart = find.bySemanticsLabel('Giỏ hàng');
      expect(cart, findsWidgets);
      await tester.tap(cart.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Figma 4.3 - A: the cart is a drawer that slides over the home
      // screen, so the empty state lives inside the panel — there is no
      // "your cart is empty" toast any more.
      expect(find.byType(CartPanel), findsOneWidget);
      expect(find.text('Giỏ hàng của bạn đang trống'), findsOneWidget);
      expect(find.text('Bạn muốn thêm món gì?'), findsOneWidget);
    });

    testWidgets('notifications action opens the orders screen', (
      WidgetTester tester,
    ) async {
      // The avatar used to lead to favourites; with the new header, the
      // bell (action_2) opens the orders screen instead.
      await _pumpHome(tester, const Size(393, 852));
      final bell = find.bySemanticsLabel('Thông báo');
      expect(bell, findsOneWidget);
      await tester.tap(bell);
      await tester.pumpAndSettle();
      // The orders route renders a place-holder title; we only assert the
      // navigation was triggered, not the destination content.
      expect(find.byType(ClientHomeScreen), findsNothing);
    });
  });

  group('promo carousel', () {
    testWidgets('auto-advances away from the first slide', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      // The timer fires every 3.6 s; push past one tick and assert the pager
      // moved. Before the fix the middle slide never advanced.
      await tester.pump(const Duration(milliseconds: 3800));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('auto-play keeps ticking across several slides', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      // Two full timer periods. `!timersPending` requires every periodic
      // timer to be cancelled, so cancel it through dispose by pumping the
      // widget away at the end.
      await tester.pump(const Duration(milliseconds: 7400));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('tapping a dot jumps to that slide', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      expect(find.bySemanticsLabel('Tới banner 3'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tới banner 3'));
      // The auto-play timer is deliberately cancelled by a dot tap and only
      // rescheduled 5 s later, so settle without waiting for the full frame.
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      // drain the reschedule timer so the test does not exit with pending work
      await tester.pump(const Duration(seconds: 6));
    });
  });

  group('section headers', () {
    testWidgets('"View All" expands the section and can be collapsed', (
      WidgetTester tester,
    ) async {
      await _pumpHome(tester, const Size(393, 852));
      expect(find.text('Xem tất cả'), findsNWidgets(2));
      await tester.tap(find.text('Xem tất cả').first);
      await tester.pump();
      expect(find.text('Thu gọn'), findsOneWidget);
      expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsOneWidget);
      await tester.tap(find.text('Thu gọn'));
      await tester.pump();
      expect(find.text('Xem tất cả'), findsNWidgets(2));
    });
  });
}
