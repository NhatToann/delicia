// Regression tests for the price-propagation bug.
//
// ## The bug
//
// An admin corrected a dish's price in the product form. The write went
// to Firebase, but **nothing else on the screen followed**:
//
//   * the product **list** and the product **form** each own their own
//     `ProductBloc`, and each bloc had *fetched* the catalogue once, when
//     the screen opened. The form re-read the catalogue after its write,
//     so the new price showed up inside the form — and nowhere else;
//   * the **customer** app was worse: `ProductsBloc` only ever did
//     one-shot `once()` reads, so the home rails, the search grid and the
//     detail page kept the price they had fetched at start-up.
//
// The fix is a realtime listener: both blocs now subscribe to the
// catalogue, so every write comes back through the same stream and every
// open screen re-renders.
//
// ## What these tests lock down
//
//   1. the admin list follows a price change made in the form,
//   2. the customer home rails follow a price change,
//   3. the customer detail page follows a price change,
//   4. the search grid follows a price change.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/product/product_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/domain/services/catalog_watcher.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

/// A catalogue fake that can also *stream*, the way Firebase does.
///
/// It implements [CatalogWatcher], so the blocs attach their listener to
/// it. [push] simulates a write made anywhere — including another
/// device or another bloc.
class StreamingAdminCatalogService extends FakeAdminCatalogService
    implements CatalogWatcher {
  StreamingAdminCatalogService({
    super.categories,
    super.products,
  });

  final StreamController<List<Productsdb>> _controller =
      StreamController<List<Productsdb>>.broadcast();

  /// Pushes a catalogue snapshot into the feed.
  void push(List<Productsdb> products) {
    if (_controller.isClosed) return;
    _controller.add(List<Productsdb>.from(products));
  }

  @override
  Stream<List<Productsdb>> watchProducts() {
    final out = StreamController<List<Productsdb>>();
    late StreamSubscription<List<Productsdb>> sub;
    out.onListen = () {
      sub = _controller.stream.listen(out.add, onError: out.addError);
      scheduleMicrotask(() async {
        if (out.isClosed) return;
        out.add(await getProducts());
      });
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }
}

/// A catalogue fake for the customer side that can stream too.
class StreamingProductsService implements ProductsService, CatalogWatcher {
  StreamingProductsService({List<Productsdb> products = const <Productsdb>[]})
      : _products = List<Productsdb>.from(products);

  List<Productsdb> _products;

  final StreamController<List<Productsdb>> _controller =
      StreamController<List<Productsdb>>.broadcast();

  /// Pushes a catalogue snapshot into the feed.
  void push(List<Productsdb> products) {
    _products = List<Productsdb>.from(products);
    if (_controller.isClosed) return;
    _controller.add(List<Productsdb>.from(products));
  }

  @override
  Stream<List<Productsdb>> watchProducts() {
    final out = StreamController<List<Productsdb>>();
    late StreamSubscription<List<Productsdb>> sub;
    out.onListen = () {
      sub = _controller.stream.listen(out.add, onError: out.addError);
      scheduleMicrotask(() {
        if (out.isClosed) return;
        out.add(List<Productsdb>.from(_products));
      });
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }

  @override
  Future<List<Productsdb>> getAllProducts() async => _products;

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async => _products;

  @override
  Future<Productsdb?> getProduct(String id) async {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async => _products;

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      _products;

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}

/// A category service that does nothing — the tests never need it.
class _NoopCategoryService implements CategoryService {
  @override
  Future<List<Category>> getCategories() async => const <Category>[];

  @override
  Future<void> addCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}
}

Productsdb _product({
  required String id,
  String name = 'Burger',
  double price = 45000,
  int status = 1,
}) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: 'Ngon',
    price: price,
    status: status,
    picture: '',
    category: 'Burger',
    categoryId: 'c1',
  );
}

void main() {
  group('the admin product list follows a price change', () {
    test('a catalogue snapshot replaces the price the list shows', () async {
      final catalog = StreamingAdminCatalogService(
        categories: const <Category>[Category(id: 'c1', category: 'Burger')],
        products: <Productsdb>[_product(id: 'p1', price: 45000)],
      );

      final bloc = ProductBloc(catalogService: catalog);
      addTearDown(bloc.close);

      bloc.add(const ProductLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.products.first.price, 45000);

      // The admin corrects the price in the form; the write comes back
      // through the listener.
      catalog.push(<Productsdb>[_product(id: 'p1', price: 75000)]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.products.first.price, 75000);
      expect(bloc.state.visibleProducts.first.price, 75000);
    });
  });

  group('the customer screens follow a price change', () {
    test('the home rails show the new price', () async {
      final service = StreamingProductsService(
        products: <Productsdb>[_product(id: 'p1', price: 45000)],
      );

      final bloc = ProductsBloc(
        categoryService: _NoopCategoryService(),
        productsService: service,
      );
      addTearDown(bloc.close);

      bloc.add(const OnGetHomeFeedEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      service.push(<Productsdb>[_product(id: 'p1', price: 75000)]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.allProducts.first.price, 75000);
      expect(bloc.state.nearbyProducts.first.price, 75000);
      expect(bloc.state.recommendedProducts.first.price, 75000);
      expect(bloc.state.bestSellers.first.price, 75000);
    });

    test('the open detail page shows the new price', () async {
      final service = StreamingProductsService(
        products: <Productsdb>[_product(id: 'p1', price: 45000)],
      );

      final bloc = ProductsBloc(
        categoryService: _NoopCategoryService(),
        productsService: service,
      );
      addTearDown(bloc.close);

      bloc.add(const OnGetDetailsProductEvent('p1'));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(bloc.state.currentProduct?.price, 45000);

      service.push(<Productsdb>[_product(id: 'p1', price: 75000)]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.currentProduct?.price, 75000);
    });

    test('the search grid shows the new price', () async {
      final service = StreamingProductsService(
        products: <Productsdb>[_product(id: 'p1', name: 'Burger')],
      );

      final bloc = ProductsBloc(
        categoryService: _NoopCategoryService(),
        productsService: service,
      );
      addTearDown(bloc.close);

      bloc.add(const OnGetAllProductsEvent());
      await Future<void>.delayed(const Duration(milliseconds: 20));

      service.push(<Productsdb>[_product(id: 'p1', name: 'Burger', price: 75000)]);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(bloc.state.searchResults.first.price, 75000);
    });
  });

  group('a catalogue without a listener keeps working', () {
    blocTest<ProductsBloc, ProductsState>(
      'the in-memory fake still loads the catalogue',
      build: () => ProductsBloc(
        categoryService: _NoopCategoryService(),
        productsService: _FakeProductsServiceStub(),
      ),
      act: (bloc) => bloc.add(const OnGetAllProductsEvent()),
      verify: (bloc) {
        expect(bloc.state.allProducts.length, 1);
      },
    );
  });
}

/// A plain, non-streaming products service — the "no listener" case.
class _FakeProductsServiceStub implements ProductsService {
  @override
  Future<List<Productsdb>> getAllProducts() async =>
      <Productsdb>[_product(id: 'p1', price: 45000)];

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      <Productsdb>[_product(id: 'p1', price: 45000)];

  @override
  Future<Productsdb?> getProduct(String id) async => _product(id: 'p1');

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async =>
      <Productsdb>[_product(id: 'p1')];

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      <Productsdb>[_product(id: 'p1')];

  @override
  Future<void> addProduct(Productsdb product) async {}

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}
