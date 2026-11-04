// UC-08 — ProductBloc (admin) tests.
//
// Covers:
//   * the catalogue + category load,
//   * the search filter and the category filter,
//   * create / update / delete / status toggle,
//   * the photo upload that happens before the row is written,
//   * the failure paths.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/product/product_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

Productsdb _product({
  required String id,
  String name = 'Burger',
  String description = '',
  String categoryId = 'c1',
  double price = 10,
  int status = 1,
}) {
  return Productsdb(
    id: id,
    nameProduct: name,
    description: description,
    price: price,
    status: status,
    picture: '',
    category: 'Burger',
    categoryId: categoryId,
  );
}

/// A tiny fake photo payload.
Uint8List _bytes() => Uint8List.fromList(<int>[1, 2, 3, 4]);

void main() {
  group('ProductBloc — load & filter', () {
    blocTest<ProductBloc, ProductState>(
      'loads the catalogue and the categories',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(
          categories: <Category>[
            const Category(id: 'c1', category: 'Burger'),
            const Category(id: 'c2', category: 'Pizza'),
          ],
          products: <Productsdb>[_product(id: 'p1')],
        ),
      ),
      act: (bloc) => bloc.add(const ProductLoadRequested()),
      expect: () => [
        isA<ProductState>().having((s) => s.isLoading, 'loading', true),
        isA<ProductState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.products.length, 'products', 1)
            .having((s) => s.categories.length, 'categories', 2),
      ],
    );

    blocTest<ProductBloc, ProductState>(
      'filters by the search text',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(),
      ),
      seed: () => ProductState(
        products: <Productsdb>[
          _product(id: 'p1', name: 'Burger'),
          _product(id: 'p2', name: 'Pizza'),
        ],
        visibleProducts: <Productsdb>[
          _product(id: 'p1', name: 'Burger'),
          _product(id: 'p2', name: 'Pizza'),
        ],
      ),
      act: (bloc) => bloc.add(const ProductSearchChanged('piz')),
      expect: () => [
        isA<ProductState>()
            .having((s) => s.query, 'query', 'piz')
            .having((s) => s.visibleProducts.length, 'visible', 1)
            .having((s) => s.visibleProducts.first.id, 'id', 'p2'),
      ],
    );

    blocTest<ProductBloc, ProductState>(
      'filters by the category',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(),
      ),
      seed: () => ProductState(
        products: <Productsdb>[
          _product(id: 'p1', categoryId: 'c1'),
          _product(id: 'p2', categoryId: 'c2'),
        ],
        visibleProducts: <Productsdb>[
          _product(id: 'p1', categoryId: 'c1'),
          _product(id: 'p2', categoryId: 'c2'),
        ],
      ),
      act: (bloc) => bloc.add(const ProductCategoryFilterChanged('c2')),
      expect: () => [
        isA<ProductState>()
            .having((s) => s.categoryId, 'category', 'c2')
            .having((s) => s.visibleProducts.length, 'visible', 1)
            .having((s) => s.visibleProducts.first.id, 'id', 'p2'),
      ],
    );
  });

  group('ProductBloc — create / update / delete', () {
    blocTest<ProductBloc, ProductState>(
      'creates a product and reloads the catalogue',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(),
      ),
      act: (bloc) => bloc.add(
        ProductCreateRequested(product: _product(id: '', name: 'Món mới')),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.products.length, 1);
        expect(bloc.state.products.first.nameProduct, 'Món mới');
      },
    );

    blocTest<ProductBloc, ProductState>(
      'stores the uploaded URL in the row',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(),
        imageUploadService: FakeImageUploadService(),
      ),
      act: (bloc) => bloc.add(
        ProductCreateRequested(
          product: _product(id: '', name: 'Có ảnh'),
          imageBytes: _bytes(),
          imageContentType: 'image/jpeg',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.products.first.picture, contains('products/'));
      },
    );

    blocTest<ProductBloc, ProductState>(
      'updates a product',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(
          products: <Productsdb>[_product(id: 'p1', name: 'Burger')],
        ),
      ),
      act: (bloc) => bloc.add(
        ProductUpdateRequested(product: _product(id: 'p1', name: 'Burger đặc biệt')),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.products.first.nameProduct, 'Burger đặc biệt');
      },
    );

    blocTest<ProductBloc, ProductState>(
      'deletes a product',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(
          products: <Productsdb>[
            _product(id: 'p1'),
            _product(id: 'p2', name: 'Pizza'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const ProductDeleteRequested('p1')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.products.length, 1);
        expect(bloc.state.products.first.id, 'p2');
      },
    );

    blocTest<ProductBloc, ProductState>(
      'toggles the stock status',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(
          products: <Productsdb>[_product(id: 'p1', status: 1)],
        ),
      ),
      act: (bloc) => bloc.add(
        ProductStatusChanged(product: _product(id: 'p1'), status: 0),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.products.first.status, 0);
        expect(bloc.state.products.first.isActive, isFalse);
      },
    );

    blocTest<ProductBloc, ProductState>(
      'surfaces a write failure',
      build: () => ProductBloc(
        catalogService: FakeAdminCatalogService(throwOnWrite: true),
      ),
      act: (bloc) => bloc.add(
        ProductCreateRequested(product: _product(id: '', name: 'Lỗi')),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });
}
