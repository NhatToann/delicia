// UC-04 — Widget tests for CartScreen.
//
// Focus: the "-" button must decrement while more than one unit is left and
// must REMOVE the line entirely when only one unit is left.

import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/presentation/client/cart/cart_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

const _pizza = ProductCart(
  uidProduct: 'pizza',
  imageProduct: 'pizza.jpg',
  nameProduct: 'Pizza Ga Cay',
  price: 14.5,
  quantity: 1,
);

Widget _wrap(CartBloc bloc, Widget child) {
  return BlocProvider<CartBloc>.value(value: bloc, child: child);
}

void main() {
  testWidgets('"-" removes the line when only one unit is left', (tester) async {
    final bloc = CartBloc();
    bloc.add(const OnAddProductToCartEvent(_pizza));

    await tester.pumpWidget(
      _wrap(bloc, const MaterialApp(home: CartScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pizza Ga Cay'), findsOneWidget);

    // Tap the "-" (remove) button.
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(bloc.state.products, isEmpty);
    expect(find.text('Pizza Ga Cay'), findsNothing);
    // The empty-cart placeholder shows up.
    expect(find.text('Without products'), findsOneWidget);
  });

  testWidgets('"-" decrements the quantity when more than one unit is left',
      (tester) async {
    final bloc = CartBloc();
    bloc.add(const OnAddProductToCartEvent(_pizza));
    bloc.add(const OnAddProductToCartEvent(_pizza));

    await tester.pumpWidget(
      _wrap(bloc, const MaterialApp(home: CartScreen())),
    );
    await tester.pumpAndSettle();

    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(bloc.state.products?.length, 1);
    expect(bloc.state.products?.first.quantity, 1);
    expect(find.text('Pizza Ga Cay'), findsOneWidget);
  });
}
