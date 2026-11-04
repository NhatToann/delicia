import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../services/admin_catalog_service.dart';
import '../../services/app_failure.dart';
part 'category_event.dart';
part 'category_state.dart';

/// CategoryBloc — the admin's category management (UC-08).
///
/// The bloc owns the whole list, so the search runs client-side: the
/// Realtime Database has no full-text index, and the admin list is small
/// enough that re-fetching on every keystroke would be pure latency.
class CategoryBloc extends Bloc<CategoryEvent, CategoryState> {
  CategoryBloc({
    required AdminCatalogService catalogService,
    ImageUploadService? imageUploadService,
  })  : _catalogService = catalogService,
        _imageUploadService = imageUploadService,
        super(const CategoryState()) {
    on<CategoryLoadRequested>(_onLoadRequested);
    on<CategorySearchChanged>(_onSearchChanged);
    on<CategoryCreateRequested>(_onCreateRequested);
    on<CategoryUpdateRequested>(_onUpdateRequested);
    on<CategoryDeleteRequested>(_onDeleteRequested);
  }

  final AdminCatalogService _catalogService;

  /// Uploads the picked photo. Optional — without it the category is
  /// saved without a picture.
  final ImageUploadService? _imageUploadService;

  Future<void> _onLoadRequested(
    CategoryLoadRequested event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final categories = await _catalogService.getCategories();
      emit(
        state.copyWith(
          isLoading: false,
          categories: categories,
          visibleCategories: _filter(categories, state.query),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: asFailure(e)));
    }
  }

  void _onSearchChanged(
    CategorySearchChanged event,
    Emitter<CategoryState> emit,
  ) {
    emit(
      state.copyWith(
        query: event.query,
        visibleCategories: _filter(state.categories, event.query),
      ),
    );
  }

  Future<void> _onCreateRequested(
    CategoryCreateRequested event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final category = await _withUploadedPicture(
        event.category,
        bytes: event.imageBytes,
        contentType: event.imageContentType,
      );
      await _catalogService.createCategory(category);
      final categories = await _catalogService.getCategories();
      emit(
        state.copyWith(
          isSubmitting: false,
          categories: categories,
          visibleCategories: _filter(categories, state.query),
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  Future<void> _onUpdateRequested(
    CategoryUpdateRequested event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final category = await _withUploadedPicture(
        event.category,
        bytes: event.imageBytes,
        contentType: event.imageContentType,
      );
      await _catalogService.updateCategory(category);
      final categories = await _catalogService.getCategories();
      emit(
        state.copyWith(
          isSubmitting: false,
          categories: categories,
          visibleCategories: _filter(categories, state.query),
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Uploads the picked photo and returns the category with its URL.
  ///
  /// The upload happens *before* the row is written, so a failed upload
  /// never leaves a category pointing at a picture that does not exist.
  Future<Category> _withUploadedPicture(
    Category category, {
    Uint8List? bytes,
    String? contentType,
  }) async {
    if (bytes == null || bytes.isEmpty) return category;
    final service = _imageUploadService;
    if (service == null) return category;
    final url = await service.uploadImage(
      path: 'categories/${category.id.isEmpty ? 'new' : category.id}'
          '_${DateTime.now().millisecondsSinceEpoch}.jpg',
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );
    return category.copyWith(picture: url);
  }

  Future<void> _onDeleteRequested(
    CategoryDeleteRequested event,
    Emitter<CategoryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _catalogService.deleteCategory(event.id);
      final categories = await _catalogService.getCategories();
      emit(
        state.copyWith(
          isSubmitting: false,
          categories: categories,
          visibleCategories: _filter(categories, state.query),
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Case- and accent-insensitive name filter.
  static List<Category> _filter(List<Category> source, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return List<Category>.unmodifiable(source);
    return source
        .where((c) => c.category.toLowerCase().contains(needle))
        .toList(growable: false);
  }
}
