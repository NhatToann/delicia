part of 'products_bloc.dart';

/// Base state for [ProductsBloc].  All loading flags default to `false`.
@immutable
class ProductsState {
  final List<Category> categories;
  final List<Productsdb> topProducts;
  final List<Productsdb> allProducts;
  final List<Productsdb> searchResults;
  final Productsdb? currentProduct;
  final List<ImageProductdb> currentImages;
  final String searchQuery;
  final String selectedCategoryId;
  final String? selectedCategoryName;
  final bool isLoadingCategories;
  final bool isLoadingTopProducts;
  final bool isLoadingSearch;
  final bool isLoadingDetails;
  final String? error;

  const ProductsState({
    this.categories = const [],
    this.topProducts = const [],
    this.allProducts = const [],
    this.searchResults = const [],
    this.currentProduct,
    this.currentImages = const [],
    this.searchQuery = '',
    this.selectedCategoryId = '',
    this.selectedCategoryName,
    this.isLoadingCategories = false,
    this.isLoadingTopProducts = false,
    this.isLoadingSearch = false,
    this.isLoadingDetails = false,
    this.error,
  });

  bool get isLoading =>
      isLoadingCategories ||
      isLoadingTopProducts ||
      isLoadingSearch ||
      isLoadingDetails;

  ProductsState copyWith({
    List<Category>? categories,
    List<Productsdb>? topProducts,
    List<Productsdb>? allProducts,
    List<Productsdb>? searchResults,
    Productsdb? currentProduct,
    bool clearCurrentProduct = false,
    List<ImageProductdb>? currentImages,
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedCategoryName,
    bool? isLoadingCategories,
    bool? isLoadingTopProducts,
    bool? isLoadingSearch,
    bool? isLoadingDetails,
    String? error,
    bool clearError = false,
  }) {
    return ProductsState(
      categories: categories ?? this.categories,
      topProducts: topProducts ?? this.topProducts,
      allProducts: allProducts ?? this.allProducts,
      searchResults: searchResults ?? this.searchResults,
      currentProduct:
          clearCurrentProduct ? null : (currentProduct ?? this.currentProduct),
      currentImages: currentImages ?? this.currentImages,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedCategoryName: selectedCategoryName ?? this.selectedCategoryName,
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingTopProducts:
          isLoadingTopProducts ?? this.isLoadingTopProducts,
      isLoadingSearch: isLoadingSearch ?? this.isLoadingSearch,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      error: clearError ? null : (error ?? this.error),
    );
  }
}