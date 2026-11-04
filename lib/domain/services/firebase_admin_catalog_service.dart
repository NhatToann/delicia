import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../../data/env/environment.dart';
import '../models/category.dart';
import '../models/product.dart';
import 'admin_catalog_service.dart';
import 'app_failure.dart';
import 'catalog_watcher.dart';

/// Firebase Realtime Database backed [AdminCatalogService] (UC-08).
///
/// ## Why every write is a full-document `PUT`
///
/// The Realtime Database's REST `PATCH` **replaces** the addressed
/// document instead of merging into it — sending `{"nameProduct": "X"}`
/// to `delicia/products/p01` wipes `price`, `picture`, `status` and the
/// rest. That mistake once wiped every price in the live catalogue.
///
/// `update()` on a `DatabaseReference` is safe (it merges the children
/// you name), so the implementation below uses `update()` for partial
/// writes and `set()` for a freshly pushed row.
class FirebaseAdminCatalogService implements AdminCatalogService, CatalogWatcher {
  FirebaseAdminCatalogService({FirebaseDatabase? database})
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

  DatabaseReference? get _categoriesRef =>
      _database?.ref('${Environment.dbRoot}/categories');

  DatabaseReference? get _productsRef =>
      _database?.ref('${Environment.dbRoot}/products');

  @override
  Future<List<Category>> getCategories() async {
    final ref = _categoriesRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final snap = await ref.once();
      return _parseCategories(snap);
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.categoriesLoad, '$e');
    }
  }

  @override
  Future<String> createCategory(Category category) async {
    final ref = _categoriesRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final newRef = ref.push();
      final id = newRef.key;
      if (id == null) {
        throw AdminServiceException(AppFailureCodes.categoryAdd);
      }
      // The key is the stable id — the products point at it through
      // `categoryId`, so it must never change.
      await newRef.set(category.copyWith(id: id).toMap());
      return id;
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.categoryAdd, '$e');
    }
  }

  @override
  Future<void> updateCategory(Category category) async {
    final ref = _categoriesRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    if (category.id.isEmpty) {
      throw AdminServiceException(AppFailureCodes.categoryUpdate);
    }
    try {
      await ref.child(category.id).update(category.toMap());
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.categoryUpdate, '$e');
    }
  }

  @override
  Future<void> deleteCategory(String id) async {
    final ref = _categoriesRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      // The products of a deleted category are deleted too — a product
      // without a category cannot be shown in the catalogue.
      final products = await _productsRef?.once();
      final value = products?.snapshot.value;
      if (value is Map) {
        final updates = <String, Object?>{};
        value.forEach((key, entry) {
          if (entry is Map && entry['categoryId'] == id) {
            updates[key.toString()] = null;
          }
        });
        if (updates.isNotEmpty) {
          await _productsRef?.update(updates);
        }
      }
      await ref.child(id).remove();
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.categoryDelete, '$e');
    }
  }

  @override
  Future<List<Productsdb>> getProducts() async {
    final ref = _productsRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final snap = await ref.once();
      return _parseProducts(snap);
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.productsLoad, '$e');
    }
  }

  @override
  Future<String> createProduct(Productsdb product) async {
    final ref = _productsRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final newRef = ref.push();
      final id = newRef.key;
      if (id == null) {
        throw AdminServiceException(AppFailureCodes.productAdd);
      }
      await newRef.set(product.copyWith(id: id).toMap());
      return id;
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.productAdd, '$e');
    }
  }

  @override
  Future<void> updateProduct(Productsdb product) async {
    final ref = _productsRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    if (product.id.isEmpty) {
      throw AdminServiceException(AppFailureCodes.productUpdate);
    }
    try {
      await ref.child(product.id).update(product.toMap());
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.productUpdate, '$e');
    }
  }

  @override
  Future<void> deleteProduct(String id) async {
    final ref = _productsRef;
    if (ref == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      await ref.child(id).remove();
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.productDelete, '$e');
    }
  }

  /// Streams the whole catalogue, starting with the current contents.
  ///
  /// The admin console needs this for the same reason the customer app
  /// does: the product **list** and the product **form** each hold their
  /// own copy of the catalogue, so a price edited in the form left the
  /// list showing the old amount. With a listener the list follows the
  /// write immediately.
  @override
  Stream<List<Productsdb>> watchProducts() {
    final ref = _productsRef;
    if (ref == null) {
      return Stream<List<Productsdb>>.value(const <Productsdb>[]);
    }
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <Productsdb>[];
      final out = <Productsdb>[];
      value.forEach((key, entry) {
        if (entry is Map) {
          out.add(
            Productsdb.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(entry),
            ),
          );
        }
      });
      return out;
    }).handleError((Object e) {
      throw AdminServiceException(AppFailureCodes.productsLoad, '$e');
    });
  }

  List<Category> _parseCategories(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const <Category>[];
    final out = <Category>[];
    value.forEach((key, entry) {
      if (entry is Map) {
        out.add(
          Category.fromMap(key.toString(), Map<dynamic, dynamic>.from(entry)),
        );
      }
    });
    return out;
  }

  List<Productsdb> _parseProducts(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const <Productsdb>[];
    final out = <Productsdb>[];
    value.forEach((key, entry) {
      if (entry is Map) {
        out.add(
          Productsdb.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(entry),
          ),
        );
      }
    });
    return out;
  }
}

/// Firebase Storage backed [ImageUploadService] (UC-08).
///
/// The admin picks a photo from the gallery; the bytes are uploaded to
/// the project's Storage bucket and the resulting download URL is stored
/// in the catalogue row.
class FirebaseImageUploadService implements ImageUploadService {
  FirebaseImageUploadService({FirebaseStorage? storage})
      : _storage = storage ?? _defaultStorage();

  final FirebaseStorage? _storage;

  static FirebaseStorage? _defaultStorage() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final storage = _storage;
    if (storage == null) {
      throw AdminServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    try {
      final ref = storage.ref(path);
      await ref.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      return await ref.getDownloadURL();
    } catch (e) {
      if (e is AdminServiceException) rethrow;
      throw AdminServiceException(AppFailureCodes.imageUpload, '$e');
    }
  }
}
