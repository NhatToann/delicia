part of 'products_bloc.dart';

/// Sort options offered by the pill row on the home screen.
enum HomeSort {
  /// `isRecommended == true` first, then by rating.
  recommended,

  /// Highest `sold` count first.
  bestSelling,

  /// Cheapest first.
  priceLowToHigh,

  /// Most expensive first.
  priceHighToLow,
}

/// Base state for [ProductsBloc].  All loading flags default to `false`.
@immutable
class ProductsState {
  final List<Category> categories;
  final List<Productsdb> topProducts;
  final List<Productsdb> allProducts;
  final List<Productsdb> searchResults;

  /// Home-screen rails, derived from [allProducts].
  final List<Productsdb> recommendedProducts;
  final List<Productsdb> bestSellers;
  final List<Productsdb> nearbyProducts;
  final Productsdb? currentProduct;
  final List<ImageProductdb> currentImages;
  final String searchQuery;
  final String selectedCategoryId;
  final String? selectedCategoryName;
  final bool isLoadingCategories;
  final bool isLoadingTopProducts;
  final bool isLoadingSearch;
  final bool isLoadingDetails;
  final bool isLoadingHomeFeed;
  final HomeSort homeSort;

  /// The last failure, carrying a stable code the UI can translate.
  final AppFailure? error;

  /// Product ids the current session has marked as favourite. Pure in-memory
  /// state for now — Firebase would need a per-user collection.
  final Set<String> favorites;

  const ProductsState({
    this.categories = const [],
    this.topProducts = const [],
    this.allProducts = const [],
    this.searchResults = const [],
    this.recommendedProducts = const [],
    this.bestSellers = const [],
    this.nearbyProducts = const [],
    this.currentProduct,
    this.currentImages = const [],
    this.searchQuery = '',
    this.selectedCategoryId = '',
    this.selectedCategoryName,
    this.isLoadingCategories = false,
    this.isLoadingTopProducts = false,
    this.isLoadingSearch = false,
    this.isLoadingDetails = false,
    this.isLoadingHomeFeed = false,
    this.homeSort = HomeSort.recommended,
    this.error,
    this.favorites = const <String>{},
  });

  bool get isLoading =>
      isLoadingCategories ||
      isLoadingTopProducts ||
      isLoadingSearch ||
      isLoadingDetails ||
      isLoadingHomeFeed;

  ProductsState copyWith({
    List<Category>? categories,
    List<Productsdb>? topProducts,
    List<Productsdb>? allProducts,
    List<Productsdb>? searchResults,
    List<Productsdb>? recommendedProducts,
    List<Productsdb>? bestSellers,
    List<Productsdb>? nearbyProducts,
    Productsdb? currentProduct,
    bool clearCurrentProduct = false,
    List<ImageProductdb>? currentImages,
    String? searchQuery,
    String? selectedCategoryId,
    String? selectedCategoryName,

    /// Clears [selectedCategoryName].
    ///
    /// `copyWith` uses `??` to merge, so passing `null` means "keep the
    /// current value" — there is no way to *unset* a nullable field
    /// otherwise. The flag gives the caller that power.
    bool clearSelectedCategoryName = false,
    bool? isLoadingCategories,
    bool? isLoadingTopProducts,
    bool? isLoadingSearch,
    bool? isLoadingDetails,
    bool? isLoadingHomeFeed,
    HomeSort? homeSort,
    AppFailure? error,
    bool clearError = false,
    Set<String>? favorites,
  }) {
    return ProductsState(
      categories: categories ?? this.categories,
      topProducts: topProducts ?? this.topProducts,
      allProducts: allProducts ?? this.allProducts,
      searchResults: searchResults ?? this.searchResults,
      recommendedProducts: recommendedProducts ?? this.recommendedProducts,
      bestSellers: bestSellers ?? this.bestSellers,
      nearbyProducts: nearbyProducts ?? this.nearbyProducts,
      currentProduct:
          clearCurrentProduct ? null : (currentProduct ?? this.currentProduct),
      currentImages: currentImages ?? this.currentImages,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      selectedCategoryName: clearSelectedCategoryName
          ? null
          : (selectedCategoryName ?? this.selectedCategoryName),
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      isLoadingTopProducts: isLoadingTopProducts ?? this.isLoadingTopProducts,
      isLoadingSearch: isLoadingSearch ?? this.isLoadingSearch,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      isLoadingHomeFeed: isLoadingHomeFeed ?? this.isLoadingHomeFeed,
      homeSort: homeSort ?? this.homeSort,
      error: clearError ? null : (error ?? this.error),
      favorites: favorites ?? this.favorites,
    );
  }
}