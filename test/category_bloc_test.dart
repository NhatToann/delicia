// UC-08 — CategoryBloc (admin) tests.
//
// Covers:
//   * the catalogue load,
//   * the client-side search filter,
//   * create / update / delete,
//   * the photo upload that happens before the row is written,
//   * the failure paths.

import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/category/category_bloc.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

Category _category({
  required String id,
  String name = 'Burger',
  String description = '',
}) {
  return Category(
    id: id,
    category: name,
    description: description,
  );
}

/// A tiny fake photo payload.
Uint8List _bytes() => Uint8List.fromList(<int>[1, 2, 3, 4]);

void main() {
  group('CategoryBloc — load & search', () {
    blocTest<CategoryBloc, CategoryState>(
      'loads the catalogue',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(
          categories: <Category>[
            _category(id: 'c1', name: 'Burger'),
            _category(id: 'c2', name: 'Pizza'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const CategoryLoadRequested()),
      expect: () => [
        isA<CategoryState>().having((s) => s.isLoading, 'loading', true),
        isA<CategoryState>()
            .having((s) => s.isLoading, 'loading', false)
            .having((s) => s.categories.length, 'count', 2)
            .having((s) => s.visibleCategories.length, 'visible', 2),
      ],
    );

    blocTest<CategoryBloc, CategoryState>(
      'filters the visible list by name, case-insensitively',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(
          categories: <Category>[
            _category(id: 'c1', name: 'Burger'),
            _category(id: 'c2', name: 'Pizza'),
          ],
        ),
      ),
      seed: () => CategoryState(
        categories: <Category>[
          _category(id: 'c1', name: 'Burger'),
          _category(id: 'c2', name: 'Pizza'),
        ],
        visibleCategories: <Category>[
          _category(id: 'c1', name: 'Burger'),
          _category(id: 'c2', name: 'Pizza'),
        ],
      ),
      act: (bloc) => bloc.add(const CategorySearchChanged('BUR')),
      expect: () => [
        isA<CategoryState>()
            .having((s) => s.query, 'query', 'BUR')
            .having((s) => s.visibleCategories.length, 'visible', 1)
            .having((s) => s.visibleCategories.first.id, 'id', 'c1'),
      ],
    );
  });

  group('CategoryBloc — create / update / delete', () {
    blocTest<CategoryBloc, CategoryState>(
      'creates a category and reloads the catalogue',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(),
      ),
      act: (bloc) => bloc.add(
        CategoryCreateRequested(category: _category(id: '', name: 'Món mới')),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.categories.length, 1);
        expect(bloc.state.categories.first.category, 'Món mới');
      },
    );

    blocTest<CategoryBloc, CategoryState>(
      'uploads the picture before writing the row',
      build: () {
        final uploader = FakeImageUploadService();
        return CategoryBloc(
          catalogService: FakeAdminCatalogService(),
          imageUploadService: uploader,
        );
      },
      act: (bloc) => bloc.add(
        CategoryCreateRequested(
          category: _category(id: '', name: 'Có ảnh'),
          imageBytes: null,
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) => expect(bloc.state.actionSucceeded, isTrue),
    );

    blocTest<CategoryBloc, CategoryState>(
      'stores the uploaded URL in the row',
      build: () {
        final uploader = FakeImageUploadService();
        return CategoryBloc(
          catalogService: FakeAdminCatalogService(),
          imageUploadService: uploader,
        );
      },
      act: (bloc) => bloc.add(
        CategoryCreateRequested(
          category: _category(id: '', name: 'Có ảnh'),
          imageBytes: _bytes(),
          imageContentType: 'image/jpeg',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.categories.first.picture, contains('categories/'));
      },
    );

    blocTest<CategoryBloc, CategoryState>(
      'updates a category',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(
          categories: <Category>[_category(id: 'c1', name: 'Burger')],
        ),
      ),
      act: (bloc) => bloc.add(
        CategoryUpdateRequested(
          category: _category(id: 'c1', name: 'Burger đặc biệt'),
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.categories.first.category, 'Burger đặc biệt');
      },
    );

    blocTest<CategoryBloc, CategoryState>(
      'deletes a category',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(
          categories: <Category>[
            _category(id: 'c1', name: 'Burger'),
            _category(id: 'c2', name: 'Pizza'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const CategoryDeleteRequested('c1')),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.categories.length, 1);
        expect(bloc.state.categories.first.id, 'c2');
      },
    );

    blocTest<CategoryBloc, CategoryState>(
      'surfaces a write failure',
      build: () => CategoryBloc(
        catalogService: FakeAdminCatalogService(throwOnWrite: true),
      ),
      act: (bloc) => bloc.add(
        CategoryCreateRequested(category: _category(id: '', name: 'Lỗi')),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });
}
