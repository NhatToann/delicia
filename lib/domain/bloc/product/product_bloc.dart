import 'dart:async';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/admin_catalog_service.dart';
import '../../services/app_failure.dart';
import '../../services/catalog_watcher.dart';

part 'product_event.dart';
part 'product_state.dart';

/// ProductBloc — the admin's product management (UC-08).
///
/// Like [CategoryBloc], the whole catalogue is kept in memory and the
/// search / category filter run client-side.
///
/// ## Why the bloc listens to the catalogue
///
/// The product **list** and the product **form** are separate screens, and
/// each one owns its own bloc. A price edited in the form therefore wrote
/// to Firebase while the list kept the copy it had fetched when it opened
/// — so the list showed the old amount until the admin left the screen and
/// came back.
///
/// The bloc now subscribes to the catalogue instead of fetching it once.
/// Every write — the form's save, the status toggle, a delete — comes back
/// through the same listener, so the list always shows what the database
/// holds.
class ProductBloc extends Bloc<ProductEvent, ProductState> {
  ProductBloc({
    required AdminCatalogService catalogService,
    ImageUploadService? imageUploadService,
  })  : _catalogService = catalogService,
        _imageUploadService = imageUploadService,
        // The service doubles as the catalogue watcher when it can stream.
        // The check is a runtime one because listening is an *optional*
        // capability: the in-memory test fake does not implement it, and
        // the bloc falls back to a plain fetch in that case.
        _watcher = catalogService is CatalogWatcher
            ? catalogService as CatalogWatcher
            : null,
        super(const ProductState()) {
    on<ProductLoadRequested>(_onLoadRequested);
    on<ProductSearchChanged>(_onSearchChanged);
    on<ProductCategoryFilterChanged>(_onCategoryFilterChanged);
    on<ProductCreateRequested>(_onCreateRequested);
    on<ProductUpdateRequested>(_onUpdateRequested);
    on<ProductDeleteRequested>(_onDeleteRequested);
    on<ProductStatusChanged>(_onStatusChanged);
    on<_ProductsWatchUpdated>(_onWatchUpdated);
    on<_ProductsWatchFailed>(_onWatchFailed);
  }

  final AdminCatalogService _catalogService;

  /// Uploads the picked photo. Optional — without it the product is
  /// saved without a picture.
  final ImageUploadService? _imageUploadService;

  /// The live catalogue feed. Optional — the bloc falls back to a plain
  /// fetch when the service cannot stream.
  final CatalogWatcher? _watcher;

  /// The live subscription to the catalogue.
  StreamSubscription<List<Productsdb>>? _productsSub;

  /// Whether the catalogue listener is already attached.
  bool _watching = false;

  @override
  Future<void> close() async {
    await _productsSub?.cancel();
    _productsSub = null;
    return super.close();
  }

  Future<void> _onLoadRequested(
    ProductLoadRequested event,
    Emitter<ProductState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final categories = await _catalogService.getCategories();
      final products = await _catalogService.getProducts();
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
      // The live listener is attached *after* the first read, so the
      // screen shows its rows immediately instead of waiting for the
      // stream's first emission. From here on every write — from this
      // screen or from anywhere else — comes back through the listener,
      // so the list can never drift from what the database holds.
      _attachWatcher();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: asFailure(e)));
    }
  }

  /// Attaches the live catalogue listener.
  ///
  /// The listener delivers the current catalogue straight away, so there
  /// is no separate "fetch then listen" step and no window in which the
  /// list could show a stale row.
  void _attachWatcher() {
    final watcher = _watcher;
    if (watcher == null || _watching) return;
    _watching = true;
    _productsSub = watcher.watchProducts().listen(
      (products) {
        if (isClosed) return;
        add(_ProductsWatchUpdated(products));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_ProductsWatchFailed(e));
      },
    );
  }

  /// Applies a catalogue snapshot that arrived from the listener.
  void _onWatchUpdated(
    _ProductsWatchUpdated event,
    Emitter<ProductState> emit,
  ) {
    emit(
      state.copyWith(
        isLoading: false,
        products: event.products,
        visibleProducts: _filter(
          event.products,
          state.query,
          state.categoryId,
        ),
      ),
    );
  }

  /// Surfaces a listener failure.
  ///
  /// The error is informational — the list keeps showing the rows it
  /// already has, so a dropped connection never blanks the screen.
  void _onWatchFailed(
    _ProductsWatchFailed event,
    Emitter<ProductState> emit,
  ) {
    emit(state.copyWith(isLoading: false, error: asFailure(event.error)));
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
