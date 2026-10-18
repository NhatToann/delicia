import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../models/category.dart';
import '../../models/image_product.dart';
import '../../models/product.dart';
import '../../services/catalog_service.dart';

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
    on<OnGetDetailsProductEvent>(_onGetDetailsProduct);
    on<OnSearchProductEvent>(
      _onSearchProduct,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );
    on<OnSelectCategoryEvent>(_onSelectCategory);
    on<OnClearCurrentProductEvent>(_onClearCurrentProduct);
    on<OnClearSearchEvent>(_onClearSearch);
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
        error: e.toString(),
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
        error: e.toString(),
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
        error: e.toString(),
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
      final results = query.trim().isEmpty && state.selectedCategoryId.isEmpty
          ? await _productsService.getTopProducts()
          : (state.selectedCategoryId.isEmpty
              ? await _productsService.searchProducts(query)
              : await _productsService.getProductsByCategory(
                  state.selectedCategoryId,
                ));
      emit(state.copyWith(
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: e.toString(),
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
      final results = state.searchQuery.trim().isEmpty
          ? await _productsService.getProductsByCategory(event.idCategory)
          : await _productsService.searchProducts(state.searchQuery);
      emit(state.copyWith(
        searchResults: results,
        isLoadingSearch: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoadingSearch: false,
        error: e.toString(),
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

  void _onClearSearch(
    OnClearSearchEvent event,
    Emitter<ProductsState> emit,
  ) {
    emit(state.copyWith(
      searchResults: const [],
      searchQuery: '',
      selectedCategoryId: '',
      selectedCategoryName: null,
    ));
  }
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