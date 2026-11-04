part of 'product_bloc.dart';

@immutable
class ProductState {
  /// True while the catalogue is loading.
  final bool isLoading;

  /// True while a create / update / delete is running.
  final bool isSubmitting;

  /// The last failure, if any.
  final AppFailure? error;

  /// Every product the platform holds.
  final List<Productsdb> products;

  /// The products matching the current search and category filter.
  final List<Productsdb> visibleProducts;

  /// The category list — used by the category picker of the form.
  final List<Category> categories;

  /// The current search text.
  final String query;

  /// The category the list is restricted to (empty = all categories).
  final String categoryId;

  /// `true` after a successful write, so the screen can close the form.
  final bool actionSucceeded;

  const ProductState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.products = const <Productsdb>[],
    this.visibleProducts = const <Productsdb>[],
    this.categories = const <Category>[],
    this.query = '',
    this.categoryId = '',
    this.actionSucceeded = false,
  });

  ProductState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    AppFailure? error,
    bool clearError = false,
    List<Productsdb>? products,
    List<Productsdb>? visibleProducts,
    List<Category>? categories,
    String? query,
    String? categoryId,
    bool? actionSucceeded,
    bool clearActionSucceeded = false,
  }) {
    return ProductState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      products: products ?? this.products,
      visibleProducts: visibleProducts ?? this.visibleProducts,
      categories: categories ?? this.categories,
      query: query ?? this.query,
      categoryId: categoryId ?? this.categoryId,
      actionSucceeded: clearActionSucceeded
          ? false
          : (actionSucceeded ?? this.actionSucceeded),
    );
  }
}
