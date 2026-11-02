part of 'product_bloc.dart';

@immutable
abstract class ProductEvent {
  const ProductEvent();
}

/// Loads the catalogue and the category list.
class ProductLoadRequested extends ProductEvent {
  const ProductLoadRequested();
}

/// Filters the visible list by name / description. Pure UI state.
class ProductSearchChanged extends ProductEvent {
  const ProductSearchChanged(this.query);
  final String query;
}

/// Restricts the visible list to one category (empty = all categories).
class ProductCategoryFilterChanged extends ProductEvent {
  const ProductCategoryFilterChanged(this.categoryId);
  final String categoryId;
}

/// Creates a product.
///
/// [imageBytes] / [imageContentType] carry the freshly picked photo. When
/// they are present the bloc uploads the picture to Storage first and
/// stores the resulting download URL in the row — the presentation layer
/// never talks to Firebase itself.
class ProductCreateRequested extends ProductEvent {
  const ProductCreateRequested({
    required this.product,
    this.imageBytes,
    this.imageContentType,
  });

  final Productsdb product;
  final Uint8List? imageBytes;
  final String? imageContentType;
}

/// Updates an existing product.
class ProductUpdateRequested extends ProductEvent {
  const ProductUpdateRequested({
    required this.product,
    this.imageBytes,
    this.imageContentType,
  });

  final Productsdb product;
  final Uint8List? imageBytes;
  final String? imageContentType;
}

/// Deletes a product.
class ProductDeleteRequested extends ProductEvent {
  const ProductDeleteRequested(this.id);
  final String id;
}

/// Turns a product on or off (sold out / back in stock).
///
/// The product itself travels with the event so the bloc never has to
/// look the row up in a list it may not have loaded yet.
class ProductStatusChanged extends ProductEvent {
  const ProductStatusChanged({required this.product, required this.status});

  final Productsdb product;
  final int status;
}
