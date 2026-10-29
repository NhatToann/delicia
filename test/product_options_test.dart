// UC-02 / UC-04 — Size options (sizes / portions) tests.
//
// The product-detail screen lets the customer pick a size, and every size
// carries its own price. These tests lock down the data contract:
//
//   * a product row carries its `options` array
//   * the options survive a round-trip through `toMap` / `fromMap`
//   * a malformed `options` value never crashes the parser
//   * a cart line remembers the size it was ordered in
//   * two sizes of the same dish are two separate cart lines

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/models/product_option.dart';
import 'package:flutter_test/flutter_test.dart';

const _options = <ProductOption>[
  ProductOption(id: 'opt1', label: 'Cá nhân (4 phần)', price: 12.90),
  ProductOption(id: 'opt2', label: 'Vừa (8 phần)', price: 16.12),
];

const _product = Productsdb(
  id: 'p01',
  nameProduct: 'Pizza Gà Cay',
  description: 'Mô tả',
  price: 12.90,
  status: 1,
  picture: 'assets/products/pizza-margherita.jpg',
  category: 'Pizza',
  categoryId: 'cat_pizza',
  options: _options,
);

void main() {
  group('Productsdb — options', () {
    test('parses the options array', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza Gà Cay',
        'price': 12.9,
        'status': 1,
        'options': <dynamic>[
          <dynamic, dynamic>{
            'id': 'opt1',
            'label': 'Cá nhân (4 phần)',
            'price': 12.9,
          },
          <dynamic, dynamic>{
            'id': 'opt2',
            'label': 'Vừa (8 phần)',
            'price': 16.12,
          },
        ],
      });

      expect(parsed.options.length, 2);
      expect(parsed.options.first.id, 'opt1');
      expect(parsed.options.first.label, 'Cá nhân (4 phần)');
      expect(parsed.options.first.price, 12.90);
      expect(parsed.options.last.price, 16.12);
    });

    test('a row without options parses into an empty list', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza',
        'price': 12.9,
      });

      expect(parsed.options, isEmpty);
    });

    test('a malformed options value never crashes the parser', () {
      final parsed = Productsdb.fromMap('p01', <dynamic, dynamic>{
        'nameProduct': 'Pizza',
        'price': 12.9,
        'options': 'not-a-list',
      });

      expect(parsed.options, isEmpty);
    });

    test('options survive a round-trip through toMap / fromMap', () {
      final encoded = _product.toMap();
      final decoded = Productsdb.fromMap(_product.id, encoded);

      expect(decoded.options, _options);
    });

    test('the options are not written when there are none', () {
      const plain = Productsdb(
        id: 'p02',
        nameProduct: 'Cà Phê',
        description: '',
        price: 3.8,
        status: 1,
        picture: '',
        category: 'Đồ Uống',
        categoryId: 'cat_drink',
      );

      expect(plain.toMap().containsKey('options'), isFalse);
    });
  });

  group('ProductCart — the selected size', () {
    test('a line without a size has a null option id', () {
      const line = ProductCart(
        uidProduct: 'p01',
        imageProduct: 'a.jpg',
        nameProduct: 'Pizza',
        price: 12.9,
        quantity: 1,
      );

      expect(line.optionId, isNull);
      expect(line.optionLabel, isNull);
      expect(line.lineKey, 'p01');
    });

    test('a line with a size keeps its id and label', () {
      const line = ProductCart(
        uidProduct: 'p01',
        imageProduct: 'a.jpg',
        nameProduct: 'Pizza',
        price: 16.12,
        quantity: 1,
        optionId: 'opt2',
        optionLabel: 'Vừa (8 phần)',
      );

      expect(line.optionId, 'opt2');
      expect(line.optionLabel, 'Vừa (8 phần)');
      // The size is part of the line's identity.
      expect(line.lineKey, 'p01#opt2');
    });

    test('the size survives a round-trip through toJson / fromJson', () {
      const line = ProductCart(
        uidProduct: 'p01',
        imageProduct: 'a.jpg',
        nameProduct: 'Pizza',
        price: 16.12,
        quantity: 2,
        optionId: 'opt2',
        optionLabel: 'Vừa (8 phần)',
      );

      final decoded = ProductCart.fromJson(line.toJson());

      expect(decoded.optionId, 'opt2');
      expect(decoded.optionLabel, 'Vừa (8 phần)');
      expect(decoded.price, 16.12);
      expect(decoded.quantity, 2);
    });
  });

  group('CartBloc — lines are keyed by product *and* size', () {
    test('the same dish in two sizes is two cart lines', () async {
      final bloc = CartBloc();
      addTearDown(bloc.close);

      bloc
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 12.9,
          quantity: 1,
          optionId: 'opt1',
          optionLabel: 'Cá nhân',
        )))
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 16.12,
          quantity: 1,
          optionId: 'opt2',
          optionLabel: 'Vừa',
        )));

      await _settle(bloc);

      expect(bloc.state.products!.length, 2);
      expect(bloc.state.products![0].optionId, 'opt1');
      expect(bloc.state.products![1].optionId, 'opt2');
    });

    test('the same dish in the same size aggregates its quantity', () async {
      final bloc = CartBloc();
      addTearDown(bloc.close);

      bloc
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 12.9,
          quantity: 1,
          optionId: 'opt1',
          optionLabel: 'Cá nhân',
        )))
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 12.9,
          quantity: 2,
          optionId: 'opt1',
          optionLabel: 'Cá nhân',
        )));

      await _settle(bloc);

      expect(bloc.state.products!.length, 1);
      expect(bloc.state.products!.first.quantity, 3);
    });

    test('the total sums every line at its own price', () async {
      final bloc = CartBloc();
      addTearDown(bloc.close);

      bloc
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 12.9,
          quantity: 1,
          optionId: 'opt1',
          optionLabel: 'Cá nhân',
        )))
        ..add(const OnAddProductToCartEvent(ProductCart(
          uidProduct: 'p01',
          imageProduct: 'a.jpg',
          nameProduct: 'Pizza',
          price: 16.12,
          quantity: 2,
          optionId: 'opt2',
          optionLabel: 'Vừa',
        )));

      await _settle(bloc);

      // 12.90 x 1 + 16.12 x 2
      expect(bloc.state.total, closeTo(12.90 + 32.24, 0.0001));
      expect(bloc.state.quantityCart, 3);
    });
  });
}

/// Lets the bloc process the events that were just added.
///
/// `CartBloc`'s handlers are synchronous, but `add()` only *schedules*
/// them — the state changes on the next event-loop turn.
Future<void> _settle(CartBloc bloc) async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
