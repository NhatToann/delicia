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