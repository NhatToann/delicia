import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/l10n/generated/app_localizations.dart';
import 'package:delicia/presentation/client/home/widgets/product_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCategoryService implements CategoryService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProductsService implements ProductsService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProductsBloc productsBloc;

  setUp(() {
    productsBloc = ProductsBloc(
      categoryService: _FakeCategoryService(),
      productsService: _FakeProductsService(),
    );
  });

  tearDown(() {
    productsBloc.close();
  });

  const sampleProduct1 = Productsdb(
    id: 'prod-1',
    nameProduct: 'Burger Nam Truffle',
    description: 'Delicious burger',
    price: 8.99,
    status: 1,
    picture: 'assets/products/burger.png',
    category: 'Burgers',
    categoryId: '1',
    rating: 4.8,
  );

  const sampleProduct2 = Productsdb(
    id: 'prod-2',
    nameProduct: 'Pizza Hawai',
    description: 'Cheesy pizza',
    price: 12.50,
    status: 1,
    picture: 'assets/products/pizza.png',
    category: 'Pizzas',
    categoryId: '2',
    rating: 4.5,
  );

  testWidgets('Tapping + button on ProductCard adds product to CartBloc', (tester) async {
    final cartBloc = CartBloc();

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<ProductsBloc>.value(value: productsBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Scaffold(
            body: ProductCard(
              product: sampleProduct1,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(cartBloc.state.products, isNull);

    // Tap the + button
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify product is in cart
    expect(cartBloc.state.products, isNotNull);
    expect(cartBloc.state.products!.length, 1);
    expect(cartBloc.state.products!.first.nameProduct, 'Burger Nam Truffle');
    expect(cartBloc.state.products!.first.quantity, 1);
  });

  testWidgets('Cart flow: decrease 1 item to 0, then tap + to select another item works smoothly', (tester) async {
    final cartBloc = CartBloc();

    // 1. Initially user has 1 item in cart
    cartBloc.add(const OnAddProductToCartEvent(ProductCart(
      uidProduct: 'prod-1',
      imageProduct: 'assets/products/burger.png',
      nameProduct: 'Burger Nam Truffle',
      price: 8.99,
      quantity: 1,
    )));
    await tester.pump();
    expect(cartBloc.state.products!.length, 1);

    // 2. User presses minus when quantity is 1 ("bấm trừ lúc còn 1 đơn hàng")
    cartBloc.add(const OnDecreaseProductQuantityToCartEvent(0));
    await tester.pump();

    // Cart is now empty
    expect(cartBloc.state.products, isEmpty);

    // 3. User chooses another dish and taps + ("bấm dấu cộng để chọn món khác")
    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider<CartBloc>.value(value: cartBloc),
          BlocProvider<ProductsBloc>.value(value: productsBloc),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('vi'),
          home: Scaffold(
            body: ProductCard(
              product: sampleProduct2,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap + on the other dish
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify the other dish was successfully added to cart
    expect(cartBloc.state.products!.length, 1);
    expect(cartBloc.state.products!.first.nameProduct, 'Pizza Hawai');
    expect(cartBloc.state.products!.first.quantity, 1);
  });
}
