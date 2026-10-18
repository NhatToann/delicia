import '../models/category.dart';
import '../models/image_product.dart';
import '../models/product.dart';

/// Errors thrown by [CategoryService] and [ProductsService]. Wrapping
/// Firebase errors makes the BLoC layer simpler (single try/catch).
class CatalogServiceException implements Exception {
  final String message;
  CatalogServiceException(this.message);
  @override
  String toString() => message;
}

/// Abstract catalog service used by [ProductsBloc]. Two implementations
/// exist:
///   - [FirebaseCategoryService] / [FirebaseProductsService] (production)
///   - Fake variants in test files
abstract class CategoryService {
  Future<List<Category>> getCategories();
  Future<void> addCategory(Category category);
  Future<void> deleteCategory(String id);
}

abstract class ProductsService {
  Future<List<Productsdb>> getTopProducts({int limit = 20});
  Future<List<Productsdb>> getAllProducts();
  Future<Productsdb?> getProduct(String id);
  Future<List<ImageProductdb>> getProductImages(String productId);
  Future<List<Productsdb>> searchProducts(String query);
  Future<List<Productsdb>> getProductsByCategory(String categoryId);
  Future<void> addProduct(Productsdb product);
  Future<void> updateStatus(String id, int status);
  Future<void> deleteProduct(String id);
}