import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../models/image_product.dart';
import '../../models/product.dart';
import '../../services/app_failure.dart';
import '../../services/catalog_service.dart';
import '../../utils/product_search.dart';

part 'products_event.dart';
part 'products_state.dart';

/// ProductsBloc — owns the catalog data (categories + products) used by
/// the client home, search and detail screens (UC-02).
///
/// State machine:
///   ProductsState(...)        → holds the lists + flags
///   FailureProductsState(err) → caught error
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc({
    required CategoryService categoryService,
    required ProductsService productsService,
  })  : _categoryService = categoryService,
        _productsService = productsService,
        super(const ProductsState()) {
    on<OnGetCategoriesEvent>(_onGetCategories);
    on<OnGetTopProductsEvent>(_onGetTopProducts);
    on<OnGetAllProductsEvent>(_onGetAllProducts);
    on<OnGetDetailsProductEvent>(_onGetDetailsProduct);
    on<OnSearchProductEvent>(
      _onSearchProduct,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
    on<OnSelectCategoryEvent>(_onSelectCategory);
    on<OnClearCurrentProductEvent>(_onClearCurrentProduct);
    on<OnClearSearchEvent>(_onClearSearch);
    on<OnStartSearchEvent>(_onStartSearch);
    on<OnClearCategoryEvent>(_onClearCategory);
    on<OnGetHomeFeedEvent>(_onGetHomeFeed);
    on<OnSortHomeFeedEvent>(_onSortHomeFeed);
    on<OnToggleFavoriteEvent>(_onToggleFavorite);
  }

  final CategoryService _categoryService;
  final ProductsService _productsService;

  Future<void> _onGetCategories(
    OnGetCategoriesEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoadingCategories: true, error: null));
    try {
      final categories = await _categoryService.getCategories();
      emit(state.copyWith(categories: categories, isLoadingCategories: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingCategories: false,
        error: asFailure(e),
      ));
    }
  }

  Future<void> _onGetTopProducts(
    OnGetTopProductsEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoadingTopProducts: true, error: null));
    try {
      final products = await _productsService.getTopProducts();
      emit(state.copyWith(topProducts: products, isLoadingTopProducts: false));
    } catch (e) {
      emit(state.copyWith(
        isLoadingTopProducts: false,
        error: asFailure(e),
      ));
    }
  }

  Future<void> _onGetAllProducts(
    OnGetAllProductsEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoadingSearch: true, error: null));
    try {
      final products = await _productsService.getAllProducts();
      // The visible list follows the same rule as the search: an active
      // query narrows it, an active category narrows it, and with neither
      // the customer sees the whole catalogue.
      final results = ProductSearch.filter(
        products,
        state.searchQuery,
        categoryId: state.selectedCategoryId,
      );
      emit(state.copyWith(
        allProducts: products,
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: asFailure(e),
      ));
    }
  }

  Future<void> _onGetDetailsProduct(
    OnGetDetailsProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoadingDetails: true, error: null));
    try {
      final product = await _productsService.getProduct(event.productId);
      if (product == null) {
        emit(state.copyWith(
          isLoadingDetails: false,
          currentProduct: null,
          currentImages: const [],
        ));
        return;
      }
      final images = await _productsService.getProductImages(event.productId);
      emit(state.copyWith(
        currentProduct: product,
        currentImages: images,
        isLoadingDetails: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingDetails: false,
        error: asFailure(e),
      ));
    }
  }

  Future<void> _onSearchProduct(
    OnSearchProductEvent event,
    Emitter<ProductsState> emit,
  ) async {
    final query = event.query;
    emit(state.copyWith(
      searchQuery: query,
      isLoadingSearch: true,
      error: null,
    ));
    try {
      // "Show everything first, filter as the user types" rule:
      //   - no query + no category  → all products
      //   - no query + category     → products in that category
      //   - query + no category     → full-text search
      //   - query + category        → full-text search restricted to the
      //     selected category
      final q = query.trim();
      if (q.isEmpty && state.selectedCategoryId.isEmpty) {
        final all = state.allProducts.isNotEmpty
            ? state.allProducts
            : await _productsService.getAllProducts();
        emit(state.copyWith(
          searchResults: all,
          isLoadingSearch: false,
        ));
        return;
      }

      // The search runs locally over the catalogue we already hold. The
      // Realtime Database has no full-text index, so the old code fetched
      // every row on each keystroke; with tens of products that is pure
      // latency for no benefit.
      final source = state.allProducts.isNotEmpty
          ? state.allProducts
          : await _productsService.getAllProducts();
      final results = ProductSearch.filter(
        source,
        q,
        categoryId: state.selectedCategoryId,
      );
      emit(state.copyWith(
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: asFailure(e),
      ));
    }
  }

  Future<void> _onSelectCategory(
    OnSelectCategoryEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategoryId: event.idCategory,
      selectedCategoryName: event.category,
      isLoadingSearch: true,
      error: null,
    ));
    try {
      final source = state.allProducts.isNotEmpty
          ? state.allProducts
          : await _productsService.getAllProducts();
      final results = ProductSearch.filter(
        source,
        state.searchQuery,
        categoryId: event.idCategory,
      );
      emit(state.copyWith(
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: asFailure(e),
      ));
    }
  }

  void _onClearCurrentProduct(
    OnClearCurrentProductEvent event,
    Emitter<ProductsState> emit,
  ) {
    emit(state.copyWith(
      currentProduct: null,
      currentImages: const [],
      isLoadingDetails: false,
    ));
  }

  /// Starts a fresh search session.
  ///
  /// The home screen and the search screen share this bloc, so the search
  /// screen opens with a clean slate instead of inheriting the category the
  /// customer happened to tap on the home screen.
  Future<void> _onStartSearch(
    OnStartSearchEvent event,
    Emitter<ProductsState> emit,
  ) async {
    // An empty name means "no category" — the chip must disappear, not
    // linger with blank text.
    final categoryName =
        (event.categoryName?.isEmpty ?? true) ? null : event.categoryName;
    emit(state.copyWith(
      searchQuery: '',
      selectedCategoryId: event.categoryId ?? '',
      selectedCategoryName: categoryName,
      clearSelectedCategoryName: categoryName == null,
      isLoadingSearch: true,
      error: null,
    ));
    try {
      final source = state.allProducts.isNotEmpty
          ? state.allProducts
          : await _productsService.getAllProducts();
      final results = ProductSearch.filter(
        source,
        '',
        categoryId: event.categoryId,
      );
      emit(state.copyWith(
        allProducts: source,
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: asFailure(e),
      ));
    }
  }

  /// Drops the category filter but keeps the current query.
  Future<void> _onClearCategory(
    OnClearCategoryEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategoryId: '',
      selectedCategoryName: null,
      clearSelectedCategoryName: true,
      isLoadingSearch: true,
      error: null,
    ));
    try {
      final source = state.allProducts.isNotEmpty
          ? state.allProducts
          : await _productsService.getAllProducts();
      final results = ProductSearch.filter(source, state.searchQuery);
      emit(state.copyWith(
        allProducts: source,
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: asFailure(e),
      ));
    }
  }

  void _onClearSearch(
    OnClearSearchEvent event,
    Emitter<ProductsState> emit,
  ) {
    // Clearing the filters must leave the customer looking at the whole
    // catalogue, not at an empty screen. The old implementation wiped
    // `searchResults` and left the grid blank until the user typed again.
    emit(state.copyWith(
      searchResults: state.allProducts,
      searchQuery: '',
      selectedCategoryId: '',
      selectedCategoryName: null,
      clearSelectedCategoryName: true,
    ));
  }

  /// Loads the home screen's three rails in one round-trip.
  ///
  /// We deliberately avoid `orderByChild('isRecommended')` because a boolean
  /// index in the Realtime Database requires a rule change; instead we fetch
  /// the active rows once and rank them here. That keeps the existing
  /// Firebase rules untouched.
  Future<void> _onGetHomeFeed(
    OnGetHomeFeedEvent event,
    Emitter<ProductsState> emit,
  ) async {
    emit(state.copyWith(isLoadingHomeFeed: true, error: null));
    try {
      final products = await _productsService.getTopProducts(limit: 60);
      final active = products.where((p) => p.isActive).toList();
      emit(state.copyWith(
        allProducts: products,
        recommendedProducts: _rank(active, HomeSort.recommended),
        bestSellers: _rank(active, HomeSort.bestSelling),
        nearbyProducts: _rank(active, state.homeSort),
        isLoadingHomeFeed: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingHomeFeed: false,
        error: asFailure(e),
      ));
    }
  }

  /// Toggles one product in the favourites set. Pure in-memory state —
  /// Firebase would require an auth-bound collection we don't have yet.
  void _onToggleFavorite(
    OnToggleFavoriteEvent event,
    Emitter<ProductsState> emit,
  ) {
    final next = Set<String>.of(state.favorites);
    if (next.contains(event.productId)) {
      next.remove(event.productId);
    } else {
      next.add(event.productId);
    }
    emit(state.copyWith(favorites: next));
  }

  /// Re-ranks the already-fetched home feed. No network call.
  void _onSortHomeFeed(
    OnSortHomeFeedEvent event,
    Emitter<ProductsState> emit,
  ) {
    final source = state.allProducts.where((p) => p.isActive).toList();
    emit(state.copyWith(
      homeSort: event.sort,
      nearbyProducts: _rank(source, event.sort),
    ));
  }

  /// Ranking rules per sort mode.
  List<Productsdb> _rank(List<Productsdb> source, HomeSort sort) {
    final list = List<Productsdb>.of(source);
    switch (sort) {
      case HomeSort.recommended:
        list.sort((a, b) {
          // Explicit recommendation flag first.
          final byFlag = _boolRank(b.isRecommended) - _boolRank(a.isRecommended);
          if (byFlag != 0) return byFlag;
          // Then by rating, then by how many people bought it.
          final byRating = b.rating.compareTo(a.rating);
          if (byRating != 0) return byRating;
          return b.sold.compareTo(a.sold);
        });
      case HomeSort.bestSelling:
        list.sort((a, b) {
          final byFlag = _boolRank(b.isBestSeller) - _boolRank(a.isBestSeller);
          if (byFlag != 0) return byFlag;
          return b.sold.compareTo(a.sold);
        });
      case HomeSort.priceLowToHigh:
        list.sort((a, b) => a.price.compareTo(b.price));
      case HomeSort.priceHighToLow:
        list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  static int _boolRank(bool v) => v ? 1 : 0;
}

/// Debounces events that fire repeatedly (search field).
EventTransformer<E> _debounce<E>(Duration duration) {
  return (events, mapper) {
    return events
        .debounce(duration)
        .asyncExpand(mapper);
  };
}

/// `stream_transform`-style debounce using only `dart:async`.
extension _DebounceExtension<T> on Stream<T> {
  Stream<T> debounce(Duration duration) {
    Timer? timer;
    final controller = StreamController<T>();
    final subscription = listen(
      (event) {
        timer?.cancel();
        timer = Timer(duration, () => controller.add(event));
      },
      onDone: () {
        timer?.cancel();
        controller.close();
      },
      onError: controller.addError,
      cancelOnError: false,
    );
    controller.onCancel = subscription.cancel;
    return controller.stream;
  }
}