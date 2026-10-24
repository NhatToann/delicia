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
    this.searchResults = const [],
    this.productById = const {},
    this.images = const [],
  });

  List<Productsdb> topProducts;
  List<Productsdb> searchResults;
  Map<String, Productsdb> productById;
  List<ImageProductdb> images;

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async {
    return topProducts;
  }

  @override
  Future<List<Productsdb>> getAllProducts() async => topProducts;

  @override
  Future<Productsdb?> getProduct(String id) async => productById[id];

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async {
    return images.where((i) => i.productId == productId).toList();
  }

  @override
  Future<List<Productsdb>> searchProducts(String query) async {
    if (query.isEmpty) return topProducts;
    return searchResults;
  }

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async {
    return searchResults
        .where((p) => p.categoryId == categoryId)
        .toList();
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
          searchResults: [_p('1', 'Beef Burger')],
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
            .having((s) => s.searchQuery, 'query', 'beef')
            .having((s) => s.isLoadingSearch, 'loading search', false),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'selecting a category narrows the results',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(
          searchResults: [_p('1', 'Pizza', categoryId: 'cat-pizza')],
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
            .having((s) => s.isLoadingSearch, 'loading search', false),
      ],
    );

    blocTest<ProductsBloc, ProductsState>(
      'clear search resets the filters',
      build: () => ProductsBloc(
        categoryService: _FakeCategoryService(),
        productsService: _FakeProductsService(),
      ),
      seed: () => ProductsState(
        searchResults: [_p('1', 'X')],
        searchQuery: 'X',
        selectedCategoryId: 'cat-x',
      ),
      act: (bloc) => bloc.add(const OnClearSearchEvent()),
      expect: () => [
        isA<ProductsState>()
            .having((s) => s.searchResults, 'results', isEmpty)
            .having((s) => s.searchQuery, 'query', '')
            .having((s) => s.selectedCategoryId, 'cat id', ''),
      ],
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