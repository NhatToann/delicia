part of 'products_bloc.dart';

@immutable
abstract class ProductsEvent {
  const ProductsEvent();
}

class OnGetCategoriesEvent extends ProductsEvent {
  const OnGetCategoriesEvent();
}

class OnGetTopProductsEvent extends ProductsEvent {
  const OnGetTopProductsEvent();
}

class OnGetAllProductsEvent extends ProductsEvent {
  const OnGetAllProductsEvent();
}

class OnGetDetailsProductEvent extends ProductsEvent {
  final String productId;
  const OnGetDetailsProductEvent(this.productId);
}

class OnSearchProductEvent extends ProductsEvent {
  final String query;
  const OnSearchProductEvent(this.query);
}

class OnSelectCategoryEvent extends ProductsEvent {
  final String idCategory;
  final String category;
  const OnSelectCategoryEvent({
    required this.idCategory,
    required this.category,
  });
}

class OnClearCurrentProductEvent extends ProductsEvent {
  const OnClearCurrentProductEvent();
}

class OnClearSearchEvent extends ProductsEvent {
  const OnClearSearchEvent();
}

/// Starts a fresh search session.
///
/// The search screen and the home screen share one [ProductsBloc], so the
/// category the customer picked on the home screen would otherwise still be
/// active when the search screen opens — the grid would silently show only
/// that one category. This event resets the filters and loads the whole
/// catalogue in one step.
///
/// Pass [categoryId] / [categoryName] to open the search screen already
/// scoped to a category (the "search within this category" flow).
class OnStartSearchEvent extends ProductsEvent {
  final String? categoryId;
  final String? categoryName;

  const OnStartSearchEvent({this.categoryId, this.categoryName});
}

/// Drops the category filter but keeps the current query.
///
/// The chip's `×` means "I did not want this category" — wiping the query
/// as well would throw away work the customer did not ask to lose.
class OnClearCategoryEvent extends ProductsEvent {
  const OnClearCategoryEvent();
}

/// Loads everything the home screen needs in one round-trip: the
/// "Recommended for you" rail and the "Best Seller" rail.
///
/// The bloc derives both lists from a single `getAllProducts()` call and
/// ranks client-side, so no extra Firebase index is required.
class OnGetHomeFeedEvent extends ProductsEvent {
  const OnGetHomeFeedEvent();
}

/// Sorts / filters the home rails. [HomeSort] and [HomeFilter] are pure
/// enums so the UI can offer the three-pill row without touching the repo.
class OnSortHomeFeedEvent extends ProductsEvent {
  final HomeSort sort;

  /// Category id to restrict to, or `null` for "all categories".
  final String? categoryId;

  const OnSortHomeFeedEvent({this.sort = HomeSort.recommended, this.categoryId});

  @override
  bool operator ==(Object other) =>
      other is OnSortHomeFeedEvent &&
      other.sort == sort &&
      other.categoryId == categoryId;

  @override
  int get hashCode => Object.hash(sort, categoryId);
}

/// Toggles a product in/out of the session's favourites set.
class OnToggleFavoriteEvent extends ProductsEvent {
  final String productId;
  const OnToggleFavoriteEvent(this.productId);
}