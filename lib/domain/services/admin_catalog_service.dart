import 'dart:async';
import 'dart:typed_data';

import '../models/category.dart';
import '../models/product.dart';
import 'app_failure.dart';

/// Errors thrown by the admin services (UC-08 / UC-09).
///
/// Like every other domain exception this one carries a stable failure
/// *code*; the presentation layer turns it into Vietnamese copy.
class AdminServiceException extends AppFailure {
  AdminServiceException(super.code, [super.detail]);
}

/// Admin-side catalogue operations (UC-08).
///
/// The client-facing [CategoryService] / [ProductsService] only expose
/// what the shopping flow needs. The admin console needs the full CRUD
/// surface, plus the ability to **update** a row — and an update has to
/// write the whole document, because the Realtime Database's REST
/// `PATCH` would drop every field it does not mention.
abstract class AdminCatalogService {
  /// Every category, including the ones without products.
  Future<List<Category>> getCategories();

  /// Creates a category and returns its generated id.
  Future<String> createCategory(Category category);

  /// Updates an existing category. The row is written in full.
  Future<void> updateCategory(Category category);

  /// Removes a category and every product that belongs to it.
  Future<void> deleteCategory(String id);

  /// Every product, including the sold-out ones.
  Future<List<Productsdb>> getProducts();

  /// Creates a product and returns its generated id.
  Future<String> createProduct(Productsdb product);

  /// Updates an existing product. The row is written in full.
  Future<void> updateProduct(Productsdb product);

  /// Removes a product.
  Future<void> deleteProduct(String id);
}

/// Uploads an image to Firebase Storage and returns its download URL.
///
/// The admin catalogue shows the pictures the restaurant uploaded, so the
/// URL returned here is what gets stored in the `picture` field.
abstract class ImageUploadService {
  /// Uploads [bytes] under [path] and returns the public download URL.
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  });
}
