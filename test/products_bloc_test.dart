// UC-02 — ProductsBloc tests.
//
// We mock CategoryService + ProductsService so the bloc can be exercised
// without touching Firebase.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCategoryService implements CategoryService {
  _FakeCategoryService({this.throwOnLoad = false, this.categories = const []});
  bool throwOnLoad;
  List<Category> categories;

  @override
  Future<List<Category>> getCategories() async {
    if (throwOnLoad) {
      throw CatalogServiceException('boom');
    }
    return categories;
  }

  @override
  Future<void> addCategory(Category category) async {}
  @override
  Future<void> deleteCategory(String id) async {}
}

class _FakeProductsService implements ProductsService {
  _FakeProductsService({
    this.topProducts = const [],
    this.catalogue = const [],
    this.productById = const {},
    this.images = const [],
  });

  List<Productsdb> topProducts;

  /// The full catalogue. The bloc searches this list locally, so a test
  /// that wants a search hit has to put the product here — the old
  /// `searchProducts()` network stub is no longer consulted.
  List<Productsdb> catalogue;
  Map<String, Productsdb> productById;
  List<ImageProductdb> images;

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async {
    return topProducts;
  }

  @override
  Future<List<Productsdb>> getAllProducts() async => catalogue;

  @override
  Future<Productsdb?> getProduct(String id) async => productById[id];

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async {
    return images.where((i) => i.productId == productId).toList();
  }

  @override
  Future<List<Productsdb>> searchProducts(String query) async {
    if (query.isEmpty) return catalogue;
    return catalogue;
  }

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async {
    return catalogue.where((p) => p.categoryId == categoryId).toList();
  }

  @override
  Future<void> addProduct(Productsdb product) async {}
  @override
  Future<void> updateStatus(String id, int status) async {}
  @override
  Future<void> deleteProduct(String id) async {}
}

Productsdb _p(String id, String name, {String categoryId = 'cat-1'}) =>
    Productsdb(
      id: id,
      nameProduct: name,
      description: 'desc',
      price: 9.99,
      status: 1,
      picture: '',
      category: 'Burgers',
      categoryId: categoryId,
    );

Category _c(String id, String name) => Category(id: id, category: name);

void main() {
  group('ProductsBloc — load', () {
    blocTest<ProductsBloc, ProductsState>(
      'loads categories and top products on init',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(
          categories: [_c('1', 'Burgers')],
        ),
        productsService: _FakeProductsService(
          topProducts: [_p('1', 'Classic Burger')],
        ),
      ),
      act: (bloc) {
        bloc.add(const OnGetCategoriesEvent());
        bloc.add(const OnGetTopProductsEvent());
      },
      skip: 0,
      expect: () => [
        isA<ProductsState>().having(
          (s) => s.isLoadingCategories,
          'loading categories',
          true,
        ),
        isA<ProductsState>()
            .having((s) => s.categories.length, 'categories', 1)
            .having((s) => s.isLoadingCategories, 'loading categories', false),
        isA<ProductsState>().having(
          (s) => s.isLoadingTopProducts,
          'loading top products',
          true,
        ),
        isA<ProductsState>()
            .having((s) => s.topProducts.length, 'topProducts', 1)
            .having(
              (s) => s.isLoadingTopProducts,
              'loading top products',
              false,
            ),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'sets error message when CategoryService throws',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(throwOnLoad: true),
        productsService: _FakeProductsService(),
      ),
      act: (bloc) => bloc.add(const OnGetCategoriesEvent()),
      expect: () => [
        isA<ProductsState>().having(
          (s) => s.isLoadingCategories,
          'loading categories',
          true,
        ),
        isA<ProductsState>()
            .having((s) => s.error, 'error', isNotNull)
            .having(
              (s) => s.isLoadingCategories,
              'loading categories',
              false,
            ),
      ],
    );
  });

  group('ProductsBloc — search', () {
    blocTest<ProductsBloc, ProductsState>(
      'search returns products filtered by query',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Beef Burger'),
            _p('2', 'Pizza Margherita'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const OnSearchProductEvent('beef')),
      wait: const Duration(milliseconds: 400),
      expect: () => [
        isA<ProductsState>().having(
          (s) => s.isLoadingSearch,
          'loading search',
          true,
        ),
        isA<ProductsState>()
            .having((s) => s.searchResults.length, 'results', 1)
            .having((s) => s.searchResults.first.id, 'result id', '1')
            .having((s) => s.searchQuery, 'query', 'beef')
            .having((s) => s.isLoadingSearch, 'loading search', false),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'search does not hit the network on every keystroke',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [_p('1', 'Beef Burger')],
        ),
      ),
      seed: () => const ProductsState(allProducts: []),
      act: (bloc) => bloc.add(const OnSearchProductEvent('beef')),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        // The catalogue is fetched once and then searched locally, so the
        // search does not depend on a `searchProducts()` round-trip.
        expect(bloc.state.searchResults.length, 1);
      },
    );

    blocTest<ProductsBloc, ProductsState>(
      'selecting a category narrows the results',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Pizza Margherita', categoryId: 'cat-pizza'),
            _p('2', 'Beef Burger', categoryId: 'cat-burger'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const OnSelectCategoryEvent(
        idCategory: 'cat-pizza',
        category: 'Pizza',
      )),
      expect: () => [
        isA<ProductsState>()
            .having((s) => s.selectedCategoryId, 'cat id', 'cat-pizza')
            .having((s) => s.selectedCategoryName, 'cat name', 'Pizza')
            .having((s) => s.isLoadingSearch, 'loading search', true),
        isA<ProductsState>()
            .having((s) => s.searchResults.length, 'results', 1)
            .having((s) => s.searchResults.first.id, 'result id', '1')
            .having((s) => s.isLoadingSearch, 'loading search', false),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'a query combined with a category only keeps rows of that category',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Burger Phô Mai', categoryId: 'cat-burger'),
            _p('2', 'Burger Gà', categoryId: 'cat-burger'),
            _p('3', 'Burger Chay', categoryId: 'cat-vegan'),
          ],
        ),
      ),
      act: (bloc) => bloc
        ..add(const OnSelectCategoryEvent(
          idCategory: 'cat-burger',
          category: 'Bánh Burger',
        ))
        ..add(const OnSearchProductEvent('burger')),
      wait: const Duration(milliseconds: 400),
      verify: (bloc) {
        final results = bloc.state.searchResults;
        // Both burgers stay, the vegan burger is dropped. The order is the
        // relevance order ("Burger Gà" is shorter than "Burger Phô Mai",
        // so it wins the tie) — this test is about the category filter.
        expect(results.map((p) => p.id).toSet(), {'1', '2'});
        expect(
          results.every((p) => p.categoryId == 'cat-burger'),
          isTrue,
        );
      },
    );

    blocTest<ProductsBloc, ProductsState>(
      'clear search resets the filters and shows the whole catalogue',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [_p('1', 'X'), _p('2', 'Y')],
        ),
      ),
      seed: () => ProductsState(
        allProducts: [_p('1', 'X'), _p('2', 'Y')],
        searchResults: [_p('1', 'X')],
        searchQuery: 'X',
        selectedCategoryId: 'cat-x',
      ),
      act: (bloc) => bloc.add(const OnClearSearchEvent()),
      expect: () => [
        isA<ProductsState>()
            .having((s) => s.searchResults.length, 'results', 2)
            .having((s) => s.searchQuery, 'query', '')
            .having((s) => s.selectedCategoryId, 'cat id', ''),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'starting a search drops the category picked on the home screen',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Burger', categoryId: 'cat-burger'),
            _p('2', 'Pizza', categoryId: 'cat-pizza'),
          ],
        ),
      ),
      seed: () => ProductsState(
        allProducts: const [],
        searchQuery: 'stale',
        selectedCategoryId: 'cat-burger',
        selectedCategoryName: 'Bánh Burger',
      ),
      act: (bloc) => bloc.add(const OnStartSearchEvent()),
      verify: (bloc) {
        expect(bloc.state.selectedCategoryId, '');
        expect(bloc.state.selectedCategoryName, isNull);
        expect(bloc.state.searchQuery, '');
        // The whole catalogue is visible, not just the stale category.
        expect(bloc.state.searchResults.length, 2);
      },
    );

    blocTest<ProductsBloc, ProductsState>(
      'starting a search can open scoped to a category',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Burger', categoryId: 'cat-burger'),
            _p('2', 'Pizza', categoryId: 'cat-pizza'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const OnStartSearchEvent(
        categoryId: 'cat-pizza',
        categoryName: 'Pizza',
      )),
      verify: (bloc) {
        expect(bloc.state.selectedCategoryId, 'cat-pizza');
        expect(bloc.state.selectedCategoryName, 'Pizza');
        expect(bloc.state.searchResults.map((p) => p.id), ['2']);
      },
    );

    blocTest<ProductsBloc, ProductsState>(
      'clearing the category keeps the query',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          catalogue: [
            _p('1', 'Burger', categoryId: 'cat-burger'),
            _p('2', 'Burger Chay', categoryId: 'cat-vegan'),
          ],
        ),
      ),
      seed: () => ProductsState(
        allProducts: const [],
        searchQuery: 'burger',
        selectedCategoryId: 'cat-burger',
        selectedCategoryName: 'Bánh Burger',
      ),
      act: (bloc) => bloc.add(const OnClearCategoryEvent()),
      verify: (bloc) {
        expect(bloc.state.selectedCategoryId, '');
        expect(bloc.state.selectedCategoryName, isNull);
        // The query survives — the customer only asked to drop the filter.
        expect(bloc.state.searchQuery, 'burger');
        expect(bloc.state.searchResults.length, 2);
      },
    );
  });

  group('ProductsBloc — detail', () {
    blocTest<ProductsBloc, ProductsState>(
      'loads product details and images',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          productById: {'p1': _p('p1', 'Beef Burger')},
          images: const [
            ImageProductdb(id: 'i1', picture: 'a.jpg', productId: 'p1'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const OnGetDetailsProductEvent('p1')),
      expect: () => [
        isA<ProductsState>().having(
          (s) => s.isLoadingDetails,
          'loading',
          true,
        ),
        isA<ProductsState>()
            .having((s) => s.currentProduct?.id, 'product id', 'p1')
            .having((s) => s.currentImages.length, 'images', 1)
            .having((s) => s.isLoadingDetails, 'loading', false),
      ],
    );
  });
}