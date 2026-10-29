// Visual check for the cart panel — renders 4.3 - A and 4.3 - B side by side
// with the Figma reference frames so the layout can be compared by eye.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/presentation/client/cart/widgets/cart_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/load_fonts.dart';

const ProductCart _shake = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'assets/figma_home/card_best_1.png',
  nameProduct: 'Strawberry Shake',
  price: 10.00,
  quantity: 2,
);

const ProductCart _lasagna = ProductCart(
  uidProduct: 'p2',
  imageProduct: 'assets/figma_home/card_best_2.png',
  nameProduct: 'Broccoli Lasagna',
  price: 12.00,
  quantity: 1,
);

Widget _panel(List<ProductCart> products) {
  final bloc = CartBloc();
  for (final p in products) {
    bloc.add(OnAddProductToCartEvent(p));
  }
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BlocProvider<CartBloc>.value(
      value: bloc,
      child: const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 330,
            height: double.infinity,
            child: CartPanel(),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() async {
    // The shared bootstrap serves *every* bundled asset and pre-decodes the
    // raster ones, so the panel's icons and thumbnails all resolve. The
    // previous local helper only served nine files, which left the
    // fallback artwork (`assets/icons/no-data.svg`) missing.
    await bootstrapGolden();
  });

  testWidgets('cart panel empty (4.3 - A)', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_panel(const <ProductCart>[]));
    await tester.pump();

    await expectLater(
      find.byType(CartPanel),
      matchesGoldenFile('cart_empty_render.png'),
    );
  });

  testWidgets('cart panel populated (4.3 - B)', (tester) async {
    tester.view
      ..physicalSize = const Size(393, 852)
      ..devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_panel(const <ProductCart>[_shake, _lasagna]));
    await tester.pump();

    // Image decoding is asynchronous and does not finish inside the fake
    // clock — step out of it so the thumbnails are actually painted.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(CartPanel),
      matchesGoldenFile('cart_populated_render.png'),
    );
  });
}
