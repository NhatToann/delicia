import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/category.dart';
import '../models/image_product.dart';
import '../models/product.dart';
import 'catalog_service.dart';

/// Firebase Realtime Database backed [CategoryService]. Production
/// implementation — tests use a fake [CategoryService] instead.
class FirebaseCategoryService implements CategoryService {
  FirebaseCategoryService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  /// Returns the project's default Firebase Database instance pointed at
  /// [Environment.firebaseDatabaseUrl]. Returns `null` if the default
  /// [FirebaseApp] has not been initialised yet.
  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _ref =>
      _database?.ref('${Environment.dbRoot}/categories');

  @override
  Future<List<Category>> getCategories() async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      final snap = await ref.once();
      return _parse(snap);
    } catch (e) {
      throw CatalogServiceException('Failed to load categories: $e');
    }
  }

  @override
  Future<void> addCategory(Category category) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final newRef = ref.push();
      await newRef.set(category.toMap());
    } catch (e) {
      throw CatalogServiceException('Failed to add category: $e');
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      await ref.child(id).remove();
    } catch (e) {
      throw CatalogServiceException('Failed to delete category: $e');
    }
  }

  List<Category> _parse(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const [];
    return value.entries
        .whereType<MapEntry<dynamic, dynamic>>()
        .map((entry) {
          final raw = entry.value;
          if (raw is! Map) return null;
          return Category.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(raw),
          );
        })
        .whereType<Category>()
        .toList();
  }
}

/// Firebase Realtime Database backed [ProductsService].
class FirebaseProductsService implements ProductsService {
  FirebaseProductsService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _ref =>
      _database?.ref('${Environment.dbRoot}/products');

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      final snap = await ref
          .orderByChild('status')
          .equalTo(1)
          .limitToFirst(limit)
          .once();
      return _parse(snap);
    } catch (e) {
      throw CatalogServiceException('Failed to load top products: $e');
    }
  }

  @override
  Future<List<Productsdb>> getAllProducts() async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.once();
      return _parse(snap);
    } catch (e) {
      throw CatalogServiceException('Failed to load products: $e');
    }
  }

  @override
  Future<Productsdb?> getProduct(String id) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.child(id).once();
      final value = snap.snapshot.value;
      if (value is! Map) return null;
      return Productsdb.fromMap(id, Map<dynamic, dynamic>.from(value));
    } catch (e) {
      throw CatalogServiceException('Failed to load product: $e');
    }
  }

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref
          .child(productId)
          .child('images')
          .once();
      final value = snap.snapshot.value;
      if (value is! Map) return const [];
      return value.entries
          .whereType<MapEntry<dynamic, dynamic>>()
          .map((entry) {
            final raw = entry.value;
            if (raw is! Map) return null;
            return ImageProductdb.fromMap(
              productId,
              entry.key.toString(),
              Map<dynamic, dynamic>.from(raw),
            );
          })
          .whereType<ImageProductdb>()
          .toList();
    } catch (e) {
      throw CatalogServiceException('Failed to load product images: $e');
    }
  }

  @override
  Future<List<Productsdb>> searchProducts(String query) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref.once();
      final all = _parse(snap);
      if (query.trim().isEmpty) return all;
      final q = query.trim().toLowerCase();
      return all
          .where((p) =>
              p.nameProduct.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q))
          .toList();
    } catch (e) {
      throw CatalogServiceException('Failed to search products: $e');
    }
  }

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final snap = await ref
          .orderByChild('categoryId')
          .equalTo(categoryId)
          .once();
      return _parse(snap);
    } catch (e) {
      throw CatalogServiceException(
        'Failed to load products by category: $e',
      );
    }
  }

  @override
  Future<void> addProduct(Productsdb product) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      final newRef = ref.push();
      await newRef.set(product.toMap());
    } catch (e) {
      throw CatalogServiceException('Failed to add product: $e');
    }
  }

  @override
  Future<void> updateStatus(String id, int status) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      await ref.child(id).child('status').set(status);
    } catch (e) {
      throw CatalogServiceException('Failed to update status: $e');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    final ref = _ref;
    if (ref == null) {
      throw CatalogServiceException('Firebase Database not initialized.');
    }
    try {
      await ref.child(id).remove();
    } catch (e) {
      throw CatalogServiceException('Failed to delete product: $e');
    }
  }

  List<Productsdb> _parse(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const [];
    return value.entries
        .whereType<MapEntry<dynamic, dynamic>>()
        .map((entry) {
          final raw = entry.value;
          if (raw is! Map) return null;
          return Productsdb.fromMap(
            entry.key.toString(),
            Map<dynamic, dynamic>.from(raw),
          );
        })
        .whereType<Productsdb>()
        .toList();
  }
}

/// Backwards-compatible alias — code written against the old concrete
/// service name (`CategoryService` / `ProductsService`) still works.
final CategoryService Function() buildCategoryService =
    FirebaseCategoryService.new;
final ProductsService Function() buildProductsService =
    FirebaseProductsService.new;