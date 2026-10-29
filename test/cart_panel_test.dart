// UC-04 — Cart panel tests.
//
// Covers the Figma screens 4.3 - A (empty cart) and 4.3 - B (populated cart)
// plus the rules that matter for the feature:
//   * the empty state renders the 4.3 - A copy
//   * the populated state renders one row per product
//   * every amount is *derived* from the product prices and [CartPricing] —
//     nothing is hardcoded
//   * the quantity stepper works and respects its lower bound
//   * a long cart scrolls while the Checkout button stays reachable

import 'package:delicia/data/env/environment.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/presentation/client/cart/widgets/cart_panel.dart';
import 'package:delicia/presentation/helpers/money.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

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

/// Builds the panel with a cart bloc seeded with [products].
Widget _harness(List<ProductCart> products, {CartBloc? bloc}) {
  final cartBloc = bloc ?? CartBloc();
  if (bloc == null) {
    for (final p in products) {
      cartBloc.add(OnAddProductToCartEvent(p));
    }
  }
  return MaterialApp(
    home: BlocProvider<CartBloc>.value(
      value: cartBloc,
      child: const Scaffold(
        backgroundColor: ColorsFrave.navOrange,
        body: CartPanel(),
      ),
    ),
  );
}

void main() {
  group('CartPanel — empty state (Figma 4.3 - A)', () {
    testWidgets('shows the 4.3 - A copy', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(const <ProductCart>[]));

      expect(find.text('Giỏ hàng'), findsOneWidget);
      // The subtitle lives in the panel header, exactly like the Figma.
      expect(find.text('Giỏ hàng của bạn đang trống'), findsOneWidget);
      expect(find.text('Bạn muốn thêm món gì?'), findsOneWidget);
    });

    testWidgets('does not render the checkout button', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(const <ProductCart>[]));

      expect(find.text('Thanh toán'), findsNothing);
    });

    testWidgets('does not render a browse CTA (Figma has none)',
        (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(const <ProductCart>[]));

      expect(find.text('Khám phá thực đơn'), findsNothing);
    });
  });

  group('CartPanel — populated state (Figma 4.3 - B)', () {
    testWidgets('renders one row per product', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(const <ProductCart>[_shake, _lasagna]),
      );
      await tester.pump();

      expect(find.text('Strawberry Shake'), findsOneWidget);
      expect(find.text('Broccoli Lasagna'), findsOneWidget);
      expect(find.text('Bạn có 2 món trong giỏ hàng'), findsOneWidget);
      expect(find.text('Thanh toán'), findsOneWidget);
    });

    testWidgets('uses the singular form for a single item', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(const <ProductCart>[_lasagna]));
      await tester.pump();

      expect(find.text('Bạn có 1 món trong giỏ hàng'), findsOneWidget);
    });

    testWidgets('derives every amount from the prices and CartPricing',
        (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // 2 x 10.00 + 1 x 12.00 = 32.00 subtotal
      await tester.pumpWidget(
        _harness(const <ProductCart>[_shake, _lasagna]),
      );
      await tester.pump();

      const subtotal = 32.00;
      expect(subtotal, 2 * 10.00 + 1 * 12.00);
      expect(CartPricing.taxOf(subtotal), closeTo(1.60, 0.001));
      expect(
        CartPricing.totalOf(subtotal),
        closeTo(subtotal + 1.60 + CartPricing.deliveryFee, 0.001),
      );

      expect(
        find.text(Money.format(subtotal)),
        findsOneWidget,
        reason: 'Subtotal must be the sum of price x quantity',
      );
      expect(
        find.text(Money.format(CartPricing.taxOf(subtotal))),
        findsOneWidget,
      );
      expect(
        find.text(Money.format(CartPricing.deliveryFee)),
        findsOneWidget,
      );
      expect(
        find.text(Money.format(CartPricing.totalOf(subtotal))),
        findsOneWidget,
      );
    });

    testWidgets('shows the line total, not the unit price', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_harness(const <ProductCart>[_shake]));
      await tester.pump();

      // 10.00 x 2 = 20.00 — the line total, not the unit price. The unit
      // price ($10.00) must not be rendered anywhere.
      expect(find.text(Money.format(10.00)), findsNothing);
      expect(find.text(Money.format(20.00)), findsWidgets);
    });

    testWidgets('never hardcodes the Figma sample amounts', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _harness(const <ProductCart>[_shake, _lasagna]),
      );
      await tester.pump();

      // The Figma frame shows $32.00 / $5.00 / $3.00 / $40.00 for a
      // different basket. With our prices the tax is $1.60 and the total
      // $36.10 — the samples must not leak in.
      expect(find.text(Money.format(5.00)), findsNothing);
      expect(find.text(Money.format(3.00)), findsNothing);
      expect(find.text(Money.format(40.00)), findsNothing);
      expect(find.text(Money.format(CartPricing.taxOf(32.00))), findsOneWidget);
      expect(
        find.text(Money.format(CartPricing.totalOf(32.00))),
        findsOneWidget,
      );
    });

    testWidgets('the + button increments the quantity', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bloc = CartBloc();
      bloc.add(const OnAddProductToCartEvent(_lasagna));

      await tester.pumpWidget(_harness(const <ProductCart>[], bloc: bloc));
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tăng số lượng'));
      await tester.pump();

      expect(bloc.state.products!.first.quantity, 2);
      // 12.00 x 2 = 24.00
      expect(find.text(Money.format(24.00)), findsWidgets);
    });

    testWidgets('the − button removes the line at quantity 1', (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final bloc = CartBloc();
      bloc.add(const OnAddProductToCartEvent(_lasagna));

      await tester.pumpWidget(_harness(const <ProductCart>[], bloc: bloc));
      await tester.pump();

      await tester.tap(find.bySemanticsLabel('Giảm số lượng'));
      await tester.pump();

      expect(bloc.state.products, isEmpty);
    });

    testWidgets('the added-at stamp is rendered when the line has one',
        (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final stamped = ProductCart(
        uidProduct: 'p3',
        imageProduct: 'assets/figma_home/card_best_1.png',
        nameProduct: 'Strawberry Shake',
        price: 10,
        quantity: 1,
        addedAt: DateTime(2024, 11, 29, 15, 0),
      );

      await tester.pumpWidget(_harness(<ProductCart>[stamped]));
      await tester.pump();

      expect(find.text('29/11/24'), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });
  });

  group('CartPanel — scrolling', () {
    testWidgets('a long cart scrolls and the Checkout button stays visible',
        (tester) async {
      tester.view
        ..physicalSize = const Size(393, 852)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final products = <ProductCart>[
        for (var i = 0; i < 12; i++)
          ProductCart(
            uidProduct: 'p$i',
            imageProduct: 'assets/figma_home/card_best_1.png',
            nameProduct: 'Item $i',
            price: 10.0 + i,
            quantity: 1,
          ),
      ];

      await tester.pumpWidget(_harness(products));
      await tester.pump();

      // The Checkout button is pinned — visible without scrolling.
      expect(find.text('Thanh toán'), findsOneWidget);
      final checkoutY = tester.getCenter(find.text('Thanh toán')).dy;
      expect(checkoutY, lessThan(852));

      // The list is long, so the first item starts near the top and the
      // summary sits far below the fold. Scrolling must bring it into view.
      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Item 0')).dy,
        lessThan(400),
        reason: 'the first row starts near the top',
      );

      await tester.drag(scrollable, const Offset(0, -1200));
      await tester.pump();
      expect(find.text('Tạm tính'), findsOneWidget);

      // The pinned button is still on screen after the scroll.
      expect(find.text('Thanh toán'), findsOneWidget);
      expect(
        tester.getCenter(find.text('Thanh toán')).dy,
        lessThan(852),
        reason: 'the Checkout button must stay pinned while the list scrolls',
      );
    });
  });
}
