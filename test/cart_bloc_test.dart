// UC-02 — CartBloc tests.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:flutter_test/flutter_test.dart';

const _p1 = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'a.jpg',
  nameProduct: 'Burger',
  price: 9.99,
  quantity: 1,
);

const _p2 = ProductCart(
  uidProduct: 'p2',
  imageProduct: 'b.jpg',
  nameProduct: 'Pizza',
  price: 14.5,
  quantity: 1,
);

void main() {
  group('CartBloc', () {
    test('initial state is empty', () {
      final bloc = CartBloc();
      expect(bloc.state.products, isNull);
      expect(bloc.state.total, 0);
      expect(bloc.state.quantityCart, 0);
      expect(bloc.state.selectedQuantity, 1);
    });

    blocTest<CartBloc, CartState>(
      'adds a product when none with the same id exists',
      build: CartBloc.new,
      act: (bloc) => bloc.add(const OnAddProductToCartEvent(_p1)),
      expect: () => [
        isA<CartState>()
            .having((s) => s.products?.length, 'items', 1)
            .having((s) => s.quantityCart, 'qty', 1)
            .having((s) => s.total, 'total', 9.99),
      ],
    );

    blocTest<CartBloc, CartState>(
      'aggregates quantity when the same product is added twice',
      build: CartBloc.new,
      act: (bloc) {
        bloc.add(const OnAddProductToCartEvent(_p1));
        bloc.add(const OnAddProductToCartEvent(_p1));
      },
      expect: () => [
        isA<CartState>().having((s) => s.products?.length, 'items', 1),
        isA<CartState>()
            .having((s) => s.products?.first.quantity, 'qty', 2)
            .having((s) => s.total, 'total', 19.98),
      ],
    );

    blocTest<CartBloc, CartState>(
      'removes a product at a given index',
      build: CartBloc.new,
      seed: () => const CartState(products: [_p1, _p2]),
      act: (bloc) => bloc.add(const OnDeleteProductToCartEvent(0)),
      expect: () => [
        isA<CartState>()
            .having((s) => s.products?.length, 'items', 1)
            .having((s) => s.products?.first.uidProduct, 'first id', 'p2'),
      ],
    );

    blocTest<CartBloc, CartState>(
      'increments and decrements quantity with bounds',
      build: () => CartBloc(),
      seed: () => const CartState(products: [_p1]),
      act: (bloc) {
        bloc
          ..add(const OnIncreaseQuantityProductToCartEvent(0))
          ..add(const OnIncreaseQuantityProductToCartEvent(0))
          ..add(const OnDecreaseProductQuantityToCartEvent(0));
      },
      expect: () => [
        isA<CartState>().having((s) => s.products?.first.quantity, 'qty', 2),
        isA<CartState>().having((s) => s.products?.first.quantity, 'qty', 3),
        isA<CartState>().having((s) => s.products?.first.quantity, 'qty', 2),
      ],
    );

    blocTest<CartBloc, CartState>(
      'decrement at quantity 1 removes the line from the cart',
      build: () => CartBloc(),
      seed: () => const CartState(products: [_p1]),
      act: (bloc) => bloc.add(const OnDecreaseProductQuantityToCartEvent(0)),
      expect: () => [
        isA<CartState>().having((s) => s.products?.length, 'items', 0),
      ],
    );

    blocTest<CartBloc, CartState>(
      'increment is capped at 99 (spec UC-04)',
      build: () => CartBloc(),
      seed: () => const CartState(
        products: [ProductCart(
          uidProduct: 'p1',
          imageProduct: 'a.jpg',
          nameProduct: 'Burger',
          price: 9.99,
          quantity: 98,
        )],
      ),
      act: (bloc) {
        bloc
          ..add(const OnIncreaseQuantityProductToCartEvent(0))
          ..add(const OnIncreaseQuantityProductToCartEvent(0))
          ..add(const OnIncreaseQuantityProductToCartEvent(0));
      },
      expect: () => [
        // first tap: 98 -> 99
        isA<CartState>().having((s) => s.products?.first.quantity, 'qty', 99),
        // second tap: already at 99, no state change (no emit)
        // third tap: same
      ],
    );

    blocTest<CartBloc, CartState>(
      'clear resets the cart',
      build: () => CartBloc(),
      seed: () => const CartState(products: [_p1, _p2], selectedQuantity: 3),
      act: (bloc) => bloc.add(const OnClearCartEvent()),
      expect: () => [
        isA<CartState>()
            .having((s) => s.products, 'products', isNull)
            .having((s) => s.total, 'total', 0)
            .having((s) => s.selectedQuantity, 'selected qty', 1),
      ],
    );
  });
}