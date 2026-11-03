// Fakes for the admin-facing services (UC-07 / UC-08 / UC-09).
//
// The admin blocs talk to Firebase through the `AdminCatalogService`,
// `ImageUploadService`, `AdminOrdersService`, `DeliveryUsersService` and
// `AdminUsersService` interfaces. The fakes below implement those
// interfaces with an in-memory store, so the bloc tests never touch the
// network.

import 'dart:async';
import 'dart:typed_data';

import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/customer_account.dart';
import 'package:delicia/domain/models/delivery_user.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/services/admin_catalog_service.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/domain/services/app_failure.dart';

/// An in-memory catalogue.
class FakeAdminCatalogService implements AdminCatalogService {
  FakeAdminCatalogService({
    List<Category> categories = const <Category>[],
    List<Productsdb> products = const <Productsdb>[],
    this.throwOnWrite = false,
  })  : _categories = List<Category>.from(categories),
        _products = List<Productsdb>.from(products);

  final List<Category> _categories;
  final List<Productsdb> _products;

  /// When true every write throws — used to test the error paths.
  bool throwOnWrite;

  /// The categories that were created during the test.
  final List<Category> createdCategories = <Category>[];

  /// The categories that were updated during the test.
  final List<Category> updatedCategories = <Category>[];

  /// The ids that were deleted during the test.
  final List<String> deletedCategoryIds = <String>[];

  /// The products that were created during the test.
  final List<Productsdb> createdProducts = <Productsdb>[];

  /// The products that were updated during the test.
  final List<Productsdb> updatedProducts = <Productsdb>[];

  /// The ids that were deleted during the test.
  final List<String> deletedProductIds = <String>[];

  int _nextId = 1;

  @override
  Future<List<Category>> getCategories() async => List<Category>.from(_categories);

  @override
  Future<List<Productsdb>> getProducts() async =>
      List<Productsdb>.from(_products);

  @override
  Future<String> createCategory(Category category) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.categoryAdd, 'boom');
    }
    final id = 'cat-${_nextId++}';
    final stored = category.copyWith(id: id);
    _categories.add(stored);
    createdCategories.add(stored);
    return id;
  }

  @override
  Future<void> updateCategory(Category category) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.categoryUpdate, 'boom');
    }
    final index = _categories.indexWhere((c) => c.id == category.id);
    if (index >= 0) _categories[index] = category;
    updatedCategories.add(category);
  }

  @override
  Future<void> deleteCategory(String id) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.categoryDelete, 'boom');
    }
    _categories.removeWhere((c) => c.id == id);
    _products.removeWhere((p) => p.categoryId == id);
    deletedCategoryIds.add(id);
  }

  @override
  Future<String> createProduct(Productsdb product) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.productAdd, 'boom');
    }
    final id = 'prod-${_nextId++}';
    final stored = product.copyWith(id: id);
    _products.add(stored);
    createdProducts.add(stored);
    return id;
  }

  @override
  Future<void> updateProduct(Productsdb product) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.productUpdate, 'boom');
    }
    final index = _products.indexWhere((p) => p.id == product.id);
    if (index >= 0) _products[index] = product;
    updatedProducts.add(product);
  }

  @override
  Future<void> deleteProduct(String id) async {
    if (throwOnWrite) {
      throw AdminServiceException(AppFailureCodes.productDelete, 'boom');
    }
    _products.removeWhere((p) => p.id == id);
    deletedProductIds.add(id);
  }
}

/// An uploader that hands back a predictable URL.
class FakeImageUploadService implements ImageUploadService {
  final List<String> uploadedPaths = <String>[];

  bool throwOnUpload = false;

  @override
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (throwOnUpload) {
      throw AdminServiceException(AppFailureCodes.imageUpload, 'boom');
    }
    uploadedPaths.add(path);
    return 'https://storage.test/$path';
  }
}

/// An in-memory order feed with a realtime stream.
///
/// The feed mirrors what Firebase does: the first snapshot is delivered
/// the moment a listener attaches, so a test never has to race the
/// subscription.
class FakeAdminOrdersService implements AdminOrdersService {
  FakeAdminOrdersService({
    List<OrderRecord> orders = const <OrderRecord>[],
    this.seedError,
  }) : _seed = List<OrderRecord>.from(orders);

  final List<OrderRecord> _seed;

  /// When set, the stream fails right after the subscription starts.
  final Object? seedError;

  final StreamController<List<OrderRecord>> _controller =
      StreamController<List<OrderRecord>>.broadcast();

  /// The assignments the admin asked for.
  final List<Map<String, String>> assignments = <Map<String, String>>[];

  /// The status changes the admin asked for.
  final List<Map<String, String>> statusUpdates = <Map<String, String>>[];

  bool throwOnAssign = false;
  bool throwOnStatusUpdate = false;

  /// Pushes a new batch of orders into the stream.
  void emit(List<OrderRecord> orders) => _controller.add(orders);

  /// Pushes an error into the stream.
  void fail(Object error) => _controller.addError(error);

  @override
  Stream<List<OrderRecord>> watchAllOrders() {
    final out = StreamController<List<OrderRecord>>();
    late StreamSubscription<List<OrderRecord>> sub;
    out.onListen = () {
      sub = _controller.stream.listen(out.add, onError: out.addError);
      scheduleMicrotask(() {
        if (out.isClosed) return;
        final error = seedError;
        if (error != null) {
          out.addError(error);
          return;
        }
        out.add(_seed);
      });
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }

  @override
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryUserId,
    required String deliveryUserName,
  }) async {
    if (throwOnAssign) {
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersAssignDelivery,
        'boom',
      );
    }
    assignments.add(<String, String>{
      'orderId': orderId,
      'deliveryUserId': deliveryUserId,
      'deliveryUserName': deliveryUserName,
    });
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    if (throwOnStatusUpdate) {
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersUpdateStatus,
        'boom',
      );
    }
    statusUpdates.add(<String, String>{
      'orderId': orderId,
      'status': status,
    });
  }
}

/// An in-memory driver feed with a realtime stream.
class FakeDeliveryUsersService implements DeliveryUsersService {
  FakeDeliveryUsersService({
    List<DeliveryUser> users = const <DeliveryUser>[],
  }) : _seed = List<DeliveryUser>.from(users);

  final List<DeliveryUser> _seed;

  final List<DeliveryUser> _users = <DeliveryUser>[];

  final StreamController<List<DeliveryUser>> _controller =
      StreamController<List<DeliveryUser>>.broadcast();

  /// The enable / disable calls the admin made.
  final List<Map<String, dynamic>> toggles = <Map<String, dynamic>>[];

  /// The drivers the admin created.
  final List<Map<String, dynamic>> created = <Map<String, dynamic>>[];

  /// The drivers the admin deleted.
  final List<Map<String, dynamic>> deleted = <Map<String, dynamic>>[];

  bool throwOnToggle = false;

  /// When set, every create throws.
  Object? throwOnCreate;

  /// When set, every delete throws.
  Object? throwOnDelete;

  /// Pushes a new batch of drivers into the stream.
  void emit(List<DeliveryUser> users) => _controller.add(users);

  /// Pushes an error into the stream.
  void fail(Object error) => _controller.addError(error);

  @override
  Stream<List<DeliveryUser>> watchDeliveryUsers() {
    final out = StreamController<List<DeliveryUser>>();
    late StreamSubscription<List<DeliveryUser>> sub;
    out.onListen = () {
      sub = _controller.stream.listen(out.add, onError: out.addError);
      scheduleMicrotask(() {
        if (out.isClosed) return;
        out.add(_seed);
      });
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }

  @override
  Future<void> setDeliveryEnabled({
    required String uid,
    required bool enabled,
  }) async {
    if (throwOnToggle) {
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryToggleEnabled,
        'boom',
      );
    }
    toggles.add(<String, dynamic>{'uid': uid, 'enabled': enabled});
    final index = _users.indexWhere((u) => u.uid == uid);
    if (index >= 0) _users[index] = _users[index].copyWith(isEnabled: enabled);
  }

  @override
  Future<String> createDeliveryDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final failure = throwOnCreate;
    if (failure != null) throw failure;
    created.add(<String, dynamic>{
      'email': email,
      'password': password,
      'firstName': firstName,
      'lastName': lastName,
      'phone': phone ?? '',
    });
    return 'driver-${created.length}';
  }

  @override
  Future<void> deleteDeliveryDriver({
    required String uid,
    required String email,
  }) async {
    final failure = throwOnDelete;
    if (failure != null) throw failure;
    deleted.add(<String, dynamic>{'uid': uid, 'email': email});
    _users.removeWhere((u) => u.uid == uid);
  }
}

/// An in-memory customer feed with a realtime stream.
class FakeAdminUsersService implements AdminUsersService {
  FakeAdminUsersService({
    List<CustomerAccount> customers = const <CustomerAccount>[],
  }) : _seed = List<CustomerAccount>.from(customers);

  final List<CustomerAccount> _seed;

  final StreamController<List<CustomerAccount>> _controller =
      StreamController<List<CustomerAccount>>.broadcast();

  /// Pushes a new batch of customers into the stream.
  void emit(List<CustomerAccount> customers) => _controller.add(customers);

  @override
  Stream<List<CustomerAccount>> watchCustomers() {
    final out = StreamController<List<CustomerAccount>>();
    late StreamSubscription<List<CustomerAccount>> sub;
    out.onListen = () {
      sub = _controller.stream.listen(out.add, onError: out.addError);
      scheduleMicrotask(() {
        if (out.isClosed) return;
        out.add(_seed);
      });
    };
    out.onCancel = () => sub.cancel();
    return out.stream;
  }
}
