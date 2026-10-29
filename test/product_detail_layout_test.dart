// UC-02 — Product detail: header safe area, spacing and the
// "added to cart" confirmation.
//
// Two regressions are guarded here:
//
//   * the yellow header band was painted from y0, so the phone's clock and
//     signal icons sat on top of the back chevron and the dish title;
//   * the "added to cart" confirmation was a modal dialog, so a double tap
//     on the CTA stacked two of them.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/models/product_option.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/presentation/client/product_detail/product_detail_screen.dart';
import 'package:delicia/presentation/client/product_detail/widgets/product_detail_geometry.dart';
import 'package:delicia/presentation/client/product_detail/widgets/product_size_row.dart';
import 'package:delicia/presentation/components/app_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _pizza = Productsdb(
  id: 'p01',
  nameProduct: 'Pizza Gà Cay',
  description: 'Mô tả món ăn ngon.',
  price: 15.00,
  status: 1,
  picture: 'assets/products/pizza-margherita.jpg',
  category: 'Pizza',
  categoryId: 'cat_pizza',
  rating: 4.7,
  // The size section only renders when the dish has options, so the
  // fixture carries a few — the layout assertions below are about
  // that section.
  options: <ProductOption>[
    ProductOption(id: 'opt1', label: 'Nho 4 phan', price: 12.90),
    ProductOption(id: 'opt2', label: 'Vua 8 phan', price: 16.12),
  ],
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
      <Productsdb>[_pizza];

  @override
  Future<List<Productsdb>> getAllProducts() async => <Productsdb>[_pizza];

  @override
  Future<Productsdb?> getProduct(String id) async => _pizza;

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async =>
      <Productsdb>[_pizza];

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      <Productsdb>[_pizza];

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}

/// Pumps the detail screen on a screen of [size] with a status bar of
/// [statusBarHeight] px.
///
/// Returns the blocs the screen was wired to, so a test can assert on
/// their state.
Future<({CartBloc cart, ProductsBloc products})> _pump(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double statusBarHeight = 0,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The status bar is what the OS draws over the app. `MediaQuery.padding`
  // is what the app has to respect.
  tester.view.padding = FakeViewPadding(top: statusBarHeight);
  tester.view.viewPadding = FakeViewPadding(top: statusBarHeight);
  addTearDown(tester.view.resetPadding);

  final cart = CartBloc();
  addTearDown(cart.close);

  final products = ProductsBloc(
    categoryService: _FakeCategoryService(),
    productsService: _FakeProductsService(),
  );
  addTearDown(products.close);

  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<ProductsBloc>.value(value: products),
          BlocProvider<CartBloc>.value(value: cart),
        ],
        child: const ProductDetailScreen(productId: 'p01'),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return (cart: cart, products: products);
}

/// The back chevron on the yellow band.
Finder _backButton() => find.bySemanticsLabel('Quay lại');

void main() {
  group('ProductDetailScreen — the header clears the status bar', () {
    testWidgets('the back chevron sits below a 44 px status bar', (
      WidgetTester tester,
    ) async {
      await _pump(tester, statusBarHeight: 44);

      final chevron = tester.getTopLeft(_backButton());
      // The chevron's own 44 px touch box is centred on the 8 x 13 glyph,
      // so the *box* starts 44 + 16 - 15.5 px below the top of the screen.
      // What matters is that the whole box is under the status bar.
      expect(chevron.dy, greaterThanOrEqualTo(44));
    });

    testWidgets('the back chevron is below the status bar on a tall notch', (
      WidgetTester tester,
    ) async {
      await _pump(tester, statusBarHeight: 90);

      expect(tester.getTopLeft(_backButton()).dy, greaterThanOrEqualTo(90));
    });

    testWidgets('the header still has breathing room without a status bar', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(
        tester.getTopLeft(_backButton()).dy,
        greaterThanOrEqualTo(ProductDetailGeometry.minHeaderTop),
      );
    });

    testWidgets('the back button is a comfortable touch target', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final size = tester.getSize(_backButton());
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });

    testWidgets('the heart button is a comfortable touch target', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final heart = find.bySemanticsLabel('Yêu thích');
      expect(heart, findsOneWidget);
      final size = tester.getSize(heart);
      expect(size.width, greaterThanOrEqualTo(40));
      expect(size.height, greaterThanOrEqualTo(40));
    });
  });

  group('ProductDetailScreen — the favourite button', () {
    testWidgets('it is not repainted into a solid orange blob', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The asset is a white disc with an orange heart outline. A
      // `ColorFilter.mode(..., BlendMode.srcIn)` repaints the white disc
      // too, which turned the whole button into a filled orange circle
      // and hid the heart.
      final heart = find.bySemanticsLabel('Yêu thích');
      expect(heart, findsOneWidget);

      final svg = find.descendant(
        of: heart,
        matching: find.byType(SvgPicture),
      );
      expect(svg, findsOneWidget);

      final picture = tester.widget<SvgPicture>(svg);
      expect(
        picture.colorFilter,
        isNull,
        reason: 'the heart asset already carries its own colours',
      );
    });

    testWidgets('tapping it marks the dish as favourite', (
      WidgetTester tester,
    ) async {
      final bloc = await _pump(tester);

      expect(bloc.products.state.favorites, isNot(contains('p01')));

      await tester.tap(find.bySemanticsLabel('Yêu thích'));
      await tester.pump();

      expect(bloc.products.state.favorites, contains('p01'));
    });

    testWidgets('tapping it again removes the favourite', (
      WidgetTester tester,
    ) async {
      final bloc = await _pump(tester);

      await tester.tap(find.bySemanticsLabel('Yêu thích'));
      await tester.pump();

      // The label flips to "Bỏ yêu thích" once the dish is a favourite.
      expect(find.bySemanticsLabel('Bỏ yêu thích'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Bỏ yêu thích'));
      await tester.pump();

      expect(bloc.products.state.favorites, isNot(contains('p01')));
    });
  });

  group('ProductDetailScreen — the rating', () {
    testWidgets('the rating is not in the yellow header', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The header used to carry a solid orange pill with the bare score.
      // It has moved down to the dish name in the white sheet.
      final score = find.text('4.7');
      expect(score, findsOneWidget);

      // The heart button is the other thing in the header, so comparing
      // against it proves the score sits below the band.
      final heart = find.bySemanticsLabel('Yêu thích');
      expect(heart, findsOneWidget);

      expect(
        tester.getTopLeft(score).dy,
        greaterThan(tester.getTopLeft(heart).dy),
        reason: 'the rating must not sit in the yellow header any more',
      );
    });

    testWidgets('the rating shows a star next to the number', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // A bare number is easy to misread as a price — the star makes it
      // unambiguous.
      final badge = find.ancestor(
        of: find.text('4.7'),
        matching: find.byType(Row),
      );
      expect(badge, findsWidgets);

      final star = find.descendant(
        of: badge.first,
        matching: find.byType(SvgPicture),
      );
      expect(star, findsOneWidget);
    });

    testWidgets('the rating sits next to the dish name', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The dish name appears twice — once in the yellow header, once in
      // the white sheet. The one in the sheet is the bold 20 pt title.
      final name = find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data == 'Pizza Gà Cay' &&
            (widget.style?.fontSize ?? 0) == 20,
      );
      expect(name, findsOneWidget);

      final score = find.text('4.7');
      expect(score, findsOneWidget);

      // Same row: the badge's vertical centre lines up with the name's.
      final nameBox = tester.getRect(name);
      final scoreBox = tester.getRect(score);

      expect(scoreBox.left, greaterThan(nameBox.left));
      expect(
        scoreBox.center.dy,
        closeTo(nameBox.center.dy, 8),
        reason: 'the badge must ride along with the title, not below it',
      );
    });
  });

  group('ProductDetailScreen — the content is inset', () {
    testWidgets('the photo does not touch the left edge', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      final photo = find.byType(ClipRRect).first;
      expect(tester.getTopLeft(photo).dx, greaterThanOrEqualTo(20));
    });

    testWidgets('the CTA keeps its label on a narrow phone', (
      WidgetTester tester,
    ) async {
      await _pump(tester, size: const Size(320, 640));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the size rows keep clear of both screen edges', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The size rows used to span the full width, so the label, the
      // price and the radio sat flush against the edges while the
      // "Kích thước / phần" heading above them was inset.
      final rows = find.byType(ProductSizeRow);
      expect(rows, findsWidgets);

      for (final row in rows.evaluate()) {
        final box = tester.getRect(find.byWidget(row.widget));
        expect(
          box.left,
          greaterThanOrEqualTo(ProductDetailGeometry.pageInset),
          reason: 'a size row must not touch the left edge',
        );
        expect(
          box.right,
          lessThanOrEqualTo(
            393 - ProductDetailGeometry.pageInset,
          ),
          reason: 'a size row must not touch the right edge',
        );
      }
    });

    testWidgets('the size rows line up with the heading above them', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The heading and the rows must share one left edge — otherwise
      // the block looks like two different alignments.
      final heading = find.text('Khẩu phần');
      expect(heading, findsOneWidget);

      final row = find.byType(ProductSizeRow).first;
      expect(
        tester.getTopLeft(row).dx,
        tester.getTopLeft(heading).dx,
      );
    });

    testWidgets('the size radio keeps clear of the right edge', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      // The radio is the last thing in the row, so the row's own right
      // edge is the radio's right edge.
      final row = find.byType(ProductSizeRow).first;
      final box = tester.getRect(row);

      expect(
        box.right,
        lessThanOrEqualTo(393 - ProductDetailGeometry.pageInset),
      );
    });

    testWidgets('the CTA keeps its label at a large text scale', (
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(1.8),
            ),
            child: child!,
          ),
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

      expect(tester.takeException(), isNull);
    });
  });

  group('ProductDetailScreen — the add-to-cart confirmation', () {
    testWidgets('shows exactly one confirmation per tap', (
      WidgetTester tester,
    ) async {
      final cart = (await _pump(tester)).cart;

      await tester.tap(find.textContaining('Thêm vào giỏ'));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(cart.state.products, hasLength(1));
    });

    testWidgets('a double tap does not stack two confirmations', (
      WidgetTester tester,
    ) async {
      final cart = (await _pump(tester)).cart;

      final cta = find.textContaining('Thêm vào giỏ');
      await tester.tap(cta);
      // No pump in between: the second tap lands while the first
      // confirmation is still being scheduled.
      await tester.tap(cta);
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      // The dish itself is still added exactly once.
      expect(cart.state.products, hasLength(1));
    });

    testWidgets('a second addition replaces the first confirmation', (
      WidgetTester tester,
    ) async {
      final cart = (await _pump(tester)).cart;

      final cta = find.textContaining('Thêm vào giỏ');
      await tester.tap(cta);
      await tester.pump();
      await tester.pump();

      // Let the first confirmation time out.
      await tester.pump(const Duration(seconds: 2));

      await tester.tap(cta);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(cart.state.products, hasLength(1));
    });
  });

  group('ProductDetailScreen — the app-wide navigation bar', () {
    testWidgets('is the same bar every other screen uses', (
      WidgetTester tester,
    ) async {
      await _pump(tester);

      expect(find.byType(AppBottomNav), findsOneWidget);
    });
  });
}
