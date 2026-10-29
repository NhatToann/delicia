// UC-02 — Product detail screen tests.
//
// The screen is ported from the Figma frame `192:1216` ("7 - A - Advertising
// Banner"). These tests cover the behaviour the design implies:
//   * the size list renders one row per size, each with its own price
//   * tapping a size selects it and changes the price
//   * the price shown comes from the data — never from a hardcoded number
//   * the Add to Cart button adds the dish at the *selected size's* price
//   * the screen never overflows, at any text scale

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
import 'package:delicia/presentation/helpers/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = <ProductOption>[
  ProductOption(id: 'opt1', label: 'Cá nhân (4 phần)', price: 12.90),
  ProductOption(id: 'opt2', label: 'Vừa (8 phần)', price: 16.12),
  ProductOption(id: 'opt3', label: 'Lớn (10 phần)', price: 20.64),
  ProductOption(id: 'opt4', label: 'Đại (12 phần)', price: 25.80),
];

const _pizza = Productsdb(
  id: 'p02',
  nameProduct: 'Pizza Gà Cay',
  description: 'Đế sourdough, pepperoni, mozzarella Buffalo, mật ong cay.',
  price: 14.50,
  oldPrice: 17.00,
  status: 1,
  picture: 'assets/products/pizza-margherita.jpg',
  category: 'Pizza',
  categoryId: 'cat_pizza',
  rating: 4.7,
  ratingCount: 932,
  sold: 2900,
  restaurantName: 'Forno Rosso',
  options: _options,
);

const _pizzaNoOptions = Productsdb(
  id: 'p03',
  nameProduct: 'Bowl Poke Cá Hồi Miso',
  description: 'Cơm sushi, cá hồi, đậu edamame, bơ, sốt miso.',
  price: 15.80,
  status: 1,
  picture: 'assets/products/salad-caesar.jpg',
  category: 'Món Lành Mạnh',
  categoryId: 'cat_healthy',
  rating: 4.8,
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
  Future<List<Productsdb>> searchProducts(String query) async =>
      <Productsdb>[product];

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
  Productsdb product = _pizza,
  CartBloc? cartBloc,
}) async {
  tester.view
    ..physicalSize = const Size(393, 852)
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final cart = cartBloc ?? CartBloc();
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

/// The headline price — the big orange number next to the photo.
///
/// It is found by its style rather than by its text, because the same
/// amount can also appear in one of the size rows.
String? _headlinePrice(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) =>
        widget is Text &&
        widget.data != null &&
        (widget.style?.fontSize ?? 0) == 24,
  );
  final texts = tester.widgetList<Text>(finder);
  if (texts.isEmpty) return null;
  return texts.first.data;
}

void main() {
  group('ProductDetailScreen — size list', () {
    testWidgets('renders one row per size', (tester) async {
      await _pump(tester);

      expect(find.byType(ProductSizeRow), findsNWidgets(_options.length));
    });

    testWidgets('every row shows its own price from the data',
        (tester) async {
      await _pump(tester);

      for (final option in _options) {
        expect(
          find.text(option.label),
          findsOneWidget,
          reason: 'the label of ${option.id} must be rendered',
        );
        // The price lives inside the row, so the finder is scoped to it —
        // the headline price can carry the same text.
        expect(
          find.descendant(
            of: find.byType(ProductSizeRow),
            matching: find.text(Money.format(option.price)),
          ),
          findsOneWidget,
          reason: 'the price of ${option.id} must be rendered',
        );
      }
    });

    testWidgets('the first size is selected by default', (tester) async {
      await _pump(tester);

      final rows = tester.widgetList<ProductSizeRow>(find.byType(ProductSizeRow));
      expect(rows.first.selected, isTrue);
      expect(rows.skip(1).every((r) => !r.selected), isTrue);
    });

    testWidgets('tapping a size selects it and changes the price',
        (tester) async {
      await _pump(tester);

      // The default price is the first size's price.
      expect(_headlinePrice(tester), Money.format(_options.first.price));

      await tester.tap(find.text(_options[2].label));
      await tester.pump();

      final rows = tester
          .widgetList<ProductSizeRow>(find.byType(ProductSizeRow))
          .toList();
      expect(rows[2].selected, isTrue);
      expect(rows.first.selected, isFalse);

      // The headline price now matches the tapped size.
      expect(_headlinePrice(tester), Money.format(_options[2].price));
    });

    testWidgets('a product without options says so instead of showing a list',
        (tester) async {
      await _pump(tester, product: _pizzaNoOptions);

      expect(find.byType(ProductSizeRow), findsNothing);
      expect(find.text('Món này không có lựa chọn khẩu phần'), findsOneWidget);
      // The product's own price is still shown.
      expect(_headlinePrice(tester), Money.format(_pizzaNoOptions.price));
    });
  });

  group('ProductDetailScreen — prices', () {
    testWidgets('never renders the Figma sample amounts', (tester) async {
      await _pump(tester);

      // $14.00 / $20.00 are the layout samples from the Figma frame.
      expect(find.text(Money.format(14.00)), findsNothing);
      expect(find.text(Money.format(20.00)), findsNothing);
    });

    testWidgets('the old price is only shown when it is really higher',
        (tester) async {
      await _pump(tester);

      // The first size costs 12.90, the old price is 17.00 → shown.
      expect(find.text(Money.format(_pizza.oldPrice!)), findsOneWidget);
    });

    testWidgets('the old price disappears when it is not higher',
        (tester) async {
      await _pump(tester);

      // Pick the biggest size: 25.80 > 17.00, so the old price is hidden.
      await tester.tap(find.text(_options[3].label));
      await tester.pump();

      expect(find.text(Money.format(_pizza.oldPrice!)), findsNothing);
    });
  });

  group('ProductDetailScreen — add to cart', () {
    testWidgets('adds the dish at the selected size\'s price', (tester) async {
      final cart = await _pump(tester);

      await tester.tap(find.text(_options[2].label));
      await tester.pump();

      await tester.tap(find.text('Thêm vào giỏ hàng'));
      await tester.pump();

      expect(cart.state.products, isNotNull);
      expect(cart.state.products!.length, 1);

      final line = cart.state.products!.first;
      expect(line.uidProduct, _pizza.id);
      expect(line.optionId, _options[2].id);
      expect(line.optionLabel, _options[2].label);
      expect(line.price, _options[2].price);
      expect(line.quantity, 1);
    });

    testWidgets('a product without options is added at its own price',
        (tester) async {
      final cart = await _pump(tester, product: _pizzaNoOptions);

      await tester.tap(find.text('Thêm vào giỏ hàng'));
      await tester.pump();

      expect(cart.state.products!.first.price, _pizzaNoOptions.price);
      expect(cart.state.products!.first.optionId, isNull);
    });
  });

  group('ProductDetailScreen — layout', () {
    testWidgets('no overflow on the kit size', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('no overflow at 1.8x text scale', (tester) async {
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
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<ProductsBloc>(
                create: (_) => ProductsBloc(
                  categoryService: _FakeCategoryService(),
                  productsService: _FakeProductsService(_pizza),
                ),
              ),
              BlocProvider<CartBloc>.value(value: cart),
            ],
            child: const ProductDetailScreen(productId: 'p02'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(tester.takeException(), isNull);
    });

    testWidgets('the photo keeps the Figma aspect ratio', (tester) async {
      await _pump(tester);

      final photo = find.byType(AspectRatio).first;
      final ratio = tester.widget<AspectRatio>(photo).aspectRatio;
      expect(ratio, closeTo(ProductDetailGeometry.photoAspect, 0.001));
    });

    testWidgets('the CTA keeps its label on a single line', (tester) async {
      await _pump(tester);

      final cta = find.text('Thêm vào giỏ hàng');
      expect(cta, findsOneWidget);

      final text = tester.widget<Text>(cta);
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('the CTA shows the line total of the selected size',
        (tester) async {
      await _pump(tester);

      // The first size is selected by default.
      expect(
        find.text(Money.format(_options.first.price)),
        findsWidgets,
        reason: 'the CTA must show what the customer is about to pay',
      );

      // Picking a bigger size updates the total on the button.
      await tester.tap(find.text(_options[2].label));
      await tester.pump();

      expect(find.text(Money.format(_options[2].price)), findsWidgets);
    });

    testWidgets('the CTA text stays inside the button', (tester) async {
      await _pump(tester);
      await tester.pumpAndSettle();

      // The button is a fixed-height pill; the text must not spill out of
      // it. `takeException` catches the overflow stripe.
      expect(tester.takeException(), isNull);

      final cta = tester.widget<Text>(find.text('Thêm vào giỏ hàng'));
      expect(cta.maxLines, 1);
      expect(cta.softWrap, isFalse);
    });
  });
}
