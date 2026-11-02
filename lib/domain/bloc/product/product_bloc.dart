import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/admin_catalog_service.dart';
import '../../services/app_failure.dart';

part 'product_event.dart';
part 'product_state.dart';

/// ProductBloc — the admin's product management (UC-08).
///
/// Like [CategoryBloc], the whole catalogue is kept in memory and the
/// search / category filter run client-side.
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({
    required AdminCatalogService catalogService,
    ImageUploadService? imageUploadService,
  })  : _catalogService = catalogService,
        _imageUploadService = imageUploadService,
        super(const ProductState()) {
    on<ProductLoadRequested>(_onLoadRequested);
    on<ProductSearchChanged>(_onSearchChanged);
    on<ProductCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ProductCreateRequested>(_onCreateRequested);
    on<ProductUpdateRequested>(_onUpdateRequested);
    on<ProductDeleteRequested>(_onDeleteRequested);
    on<ProductStatusChanged>(_onStatusChanged);
  }

  final AdminCatalogService _catalogService;

  /// Uploads the picked photo. Optional — without it the product is
  /// saved without a picture.
  final ImageUploadService? _imageUploadService;

  Future<void> _onLoadRequested(
    ProductLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final products = await _catalogService.getProducts();
      final categories = await _catalogService.getCategories();
      emit(
        state.copyWith(
          isLoading: false,
          products: products,
          categories: categories,
          visibleProducts: _filter(
            products,
            state.query,
            state.categoryId,
          ),
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: asFailure(e)));
    }
  }

  void _onSearchChanged(
    ProductSearchChanged event,
    Emitter<ProductState> emit,
  ) {
    emit(
      state.copyWith(
        query: event.query,
        visibleProducts: _filter(
          state.products,
          event.query,
          state.categoryId,
        ),
      ),
    );
  }

  void _onCategoryFilterChanged(
    ProductCategoryFilterChanged event,
    Emitter<ProductState> emit,
  ) {
    emit(
      state.copyWith(
        categoryId: event.categoryId,
        visibleProducts: _filter(
          state.products,
          state.query,
          event.categoryId,
        ),
      ),
    );
  }

  Future<void> _onCreateRequested(
    ProductCreateRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final product = await _withUploadedPicture(
        event.product,
        bytes: event.imageBytes,
        contentType: event.imageContentType,
      );
      await _catalogService.createProduct(product);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  Future<void> _onUpdateRequested(
    ProductUpdateRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final product = await _withUploadedPicture(
        event.product,
        bytes: event.imageBytes,
        contentType: event.imageContentType,
      );
      await _catalogService.updateProduct(product);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Uploads the picked photo and returns the product with its URL.
  ///
  /// The upload happens *before* the row is written, so a failed upload
  /// never leaves a product pointing at a picture that does not exist.
  Future<Productsdb> _withUploadedPicture(
    Productsdb product, {
    Uint8List? bytes,
    String? contentType,
  }) async {
    if (bytes == null || bytes.isEmpty) return product;
    final service = _imageUploadService;
    if (service == null) return product;
    final url = await service.uploadImage(
      path: 'products/${product.id.isEmpty ? 'new' : product.id}'
          '_${DateTime.now().millisecondsSinceEpoch}.jpg',
      bytes: bytes,
      contentType: contentType ?? 'image/jpeg',
    );
    return product.copyWith(picture: url);
  }

  Future<void> _onDeleteRequested(
    ProductDeleteRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _catalogService.deleteProduct(event.id);
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  Future<void> _onStatusChanged(
    ProductStatusChanged event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final current = state.products.firstWhere(
        (p) => p.id == event.product.id,
        orElse: () => event.product,
      );
      await _catalogService.updateProduct(
        current.copyWith(status: event.status),
      );
      await _reload(emit);
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Re-reads the catalogue after a write and re-applies the filters.
  Future<void> _reload(Emitter<ProductState> emit) async {
    final products = await _catalogService.getProducts();
    emit(
      state.copyWith(
        isSubmitting: false,
        products: products,
        visibleProducts: _filter(
          products,
          state.query,
          state.categoryId,
        ),
        actionSucceeded: true,
      ),
    );
  }

  /// Applies the search text and the category filter.
  ///
  /// The search is accent-insensitive, so "truffle" finds "Truffle" and
  /// "bun bo" finds "Bún Bò" — the same rule the client search uses.
  static List<Productsdb> _filter(
    List<Productsdb> source,
    String query,
    String categoryId,
  ) {
    final needle = query.trim().toLowerCase();
    return source.where((product) {
      if (categoryId.isNotEmpty && product.categoryId != categoryId) {
        return false;
      }
      if (needle.isEmpty) return true;
      return product.nameProduct.toLowerCase().contains(needle) ||
          product.description.toLowerCase().contains(needle);
    }).toList(growable: false);
  }
}
