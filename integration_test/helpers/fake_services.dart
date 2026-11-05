// In-memory doubles for every service the app talks to.
//
// The integration tests drive the **real** widgets, blocs and router — the
// only thing they replace is Firebase. Swapping the transport for an
// in-memory store keeps the end-to-end flow real (same blocs, same
// screens, same navigation) while making the test deterministic and
// runnable without a network.
//
// Nothing here touches the network, the clock is injected and every
// service returns data the test controls.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:delicia/domain/models/address.dart';
import 'package:delicia/domain/models/category.dart';
import 'package:delicia/domain/models/client_address.dart';
import 'package:delicia/domain/models/customer_account.dart';
import 'package:delicia/domain/models/delivery_user.dart';
import 'package:delicia/domain/models/image_product.dart';
import 'package:delicia/domain/models/order_item.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/price_breakdown.dart';
import 'package:delicia/domain/models/product.dart';
import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/admin_catalog_service.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:delicia/domain/services/catalog_service.dart';
import 'package:delicia/domain/services/client_address_service.dart';
import 'package:delicia/domain/services/client_orders_service.dart';
import 'package:delicia/domain/services/client_user_service.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/domain/services/realtime_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

// ---------------------------------------------------------------------------
// Seed data
// ---------------------------------------------------------------------------

/// The catalogue the integration tests browse.
const List<Category> seedCategories = <Category>[
  Category(id: 'cat_burger', category: 'Burger', icon: 'burger', color: 0xFFE95322),
  Category(id: 'cat_pizza', category: 'Pizza', icon: 'pizza', color: 0xFF2EC4B6),
];

final List<Productsdb> seedProducts = <Productsdb>[
  Productsdb(
    id: 'p01',
    nameProduct: 'Burger Nấm Truffle Đặc Trưng',
    description: 'Burger bò phô mai cheddar và nấm truffle',
    price: 89000,
    oldPrice: 120000,
    status: 1,
    picture: 'assets/products/burger.png',
    category: 'Burger',
    categoryId: 'cat_burger',
    rating: 4.8,
    ratingCount: 210,
    sold: 430,
    isRecommended: true,
    isBestSeller: true,
    restaurantName: 'Bếp Delicia',
  ),
  Productsdb(
    id: 'p02',
    nameProduct: 'Pizza Phô Mai Chanh Muối',
    description: 'Pizza viên bò mềm và phô mai mozzarella',
    price: 149000,
    oldPrice: 179000,
    status: 1,
    picture: 'assets/products/pizza.png',
    category: 'Pizza',
    categoryId: 'cat_pizza',
    rating: 4.6,
    ratingCount: 158,
    sold: 310,
    isRecommended: true,
    isBestSeller: true,
    restaurantName: 'Bếp Delicia',
  ),
  Productsdb(
    id: 'p03',
    nameProduct: 'Gà Sốt Mật Ong',
    description: '�ùi gà nướng mật ong thơm lừng',
    price: 79000,
    oldPrice: 99000,
    status: 1,
    picture: 'assets/products/chicken.png',
    category: 'Món lợi',
    categoryId: 'cat_burger',
    rating: 4.4,
    ratingCount: 96,
    sold: 220,
    isRecommended: false,
    isBestSeller: true,
    restaurantName: 'Bếp Delicia',
  ),
];

// ---------------------------------------------------------------------------
// Auth
// ---------------------------------------------------------------------------

/// An [AuthService] backed by an in-memory account table.
///
/// The default account is a **client** (`rolId == 1`), which is the role
/// the customer journey runs as. Pass [rolId] to sign in as the admin
/// (`2`) or the courier (`3`) instead.
///
/// The role ids follow the convention the screens use: `1` = customer,
/// `2` = restaurant, `3` = courier (see `SelectRoleScreen`).
class FakeAuthService implements AuthService {
  FakeAuthService({this.rolId = 1, this.email = 'khach@delicia.com'});

  /// The role the fake account carries.
  final int rolId;

  /// The email the fake account is registered with.
  final String email;

  User? _signedIn;

  @override
  Future<User> login(String email, String password) async {
    _signedIn = User(
      uid: 'uid-$rolId',
      email: this.email,
      firstName: 'Nguyễn',
      lastName: 'Test',
      phone: '0901234567',
      rolId: rolId,
    );
    return _signedIn!;
  }

  @override
  Future<User?> checkLogin() async => _signedIn;

  @override
  fb.User? get currentFirebaseUser => null;

  @override
  Stream<fb.User?> get authStateChanges => const Stream<fb.User?>.empty();

  @override
  Future<User> loginWithGoogle() async => login(email, 'google');

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<void> logout() async => _signedIn = null;

  @override
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 1,
  }) async {
    _signedIn = User(
      uid: 'uid-new',
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      rolId: rolId,
    );
    return _signedIn!;
  }

  @override
  Future<User> updateProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String phone,
    required String dateOfBirth,
    Uint8List? profileImageBytes,
    String? profileImageContentType,
  }) async => user.copyWith(
    firstName: firstName,
    lastName: lastName,
    phone: phone,
    dateOfBirth: dateOfBirth,
  );
}

// ---------------------------------------------------------------------------
// Catalogue
// ---------------------------------------------------------------------------

/// An in-memory catalogue shared by the client and the admin sides.
class FakeCatalogService implements CategoryService, ProductsService {
  FakeCatalogService({List<Productsdb>? products})
    : _products = List<Productsdb>.from(products ?? seedProducts);

  final List<Productsdb> _products;

  @override
  Future<List<Category>> getCategories() async => seedCategories;

  @override
  Future<void> addCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<List<Productsdb>> getTopProducts({int limit = 20}) async =>
      _products.where((p) => p.status == 1).take(limit).toList();

  @override
  Future<List<Productsdb>> getAllProducts() async => List<Productsdb>.from(_products);

  @override
  Future<Productsdb?> getProduct(String id) async {
    for (final p in _products) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  Future<List<ImageProductdb>> getProductImages(String productId) async =>
      const <ImageProductdb>[];

  @override
  Future<List<Productsdb>> searchProducts(String query) async =>
      _products.where((p) => p.matchesQuery(query)).toList();

  @override
  Future<List<Productsdb>> getProductsByCategory(String categoryId) async =>
      _products.where((p) => p.categoryId == categoryId).toList();

  @override
  Future<void> addProduct(Productsdb product) async => _products.add(product);

  @override
  Future<void> updateStatus(String id, int status) async {}

  @override
  Future<void> deleteProduct(String id) async =>
      _products.removeWhere((p) => p.id == id);
}

/// The admin-side catalogue, sharing the same rows as [FakeCatalogService].
class FakeAdminCatalogService implements AdminCatalogService {
  FakeAdminCatalogService(this._catalog);

  final FakeCatalogService _catalog;

  @override
  Future<List<Category>> getCategories() async => seedCategories;

  @override
  Future<String> createCategory(Category category) async => category.id;

  @override
  Future<void> updateCategory(Category category) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<List<Productsdb>> getProducts() async => _catalog.getAllProducts();

  @override
  Future<String> createProduct(Productsdb product) async => product.id;

  @override
  Future<void> updateProduct(Productsdb product) async {}

  @override
  Future<void> deleteProduct(String id) async {}
}

/// An uploader that hands back a predictable URL.
class FakeImageUploadService implements ImageUploadService {
  @override
  Future<String> uploadImage({
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async => 'https://storage.test/$path';
}

// ---------------------------------------------------------------------------
// Orders
// ---------------------------------------------------------------------------

/// The single source of truth for the order table in the integration tests.
///
/// Both the client-side ([OrdersService]) and the admin-side
/// ([AdminOrdersService]) views read the same rows, so an order the
/// customer places is immediately visible to the restaurant and to the
/// courier — exactly like the real Realtime Database.
class FakeOrderStore {
  FakeOrderStore({List<OrderRecord>? seed})
    : _orders = <String, OrderRecord>{
        for (final o in seed ?? const <OrderRecord>[]) o.id: o,
      };

  final Map<String, OrderRecord> _orders;

  final StreamController<List<OrderRecord>> _controller =
      StreamController<List<OrderRecord>>.broadcast();

  int _nextId = 1;

  /// Every order, newest first.
  List<OrderRecord> all() {
    final out = _orders.values.toList();
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  OrderRecord? byId(String id) => _orders[id];

  void put(OrderRecord order) {
    _orders[order.id] = order;
    _controller.add(all());
  }

  void remove(String id) {
    _orders.remove(id);
    _controller.add(all());
  }

  /// Pushes the current table into every listener.
  void publish() => _controller.add(all());

  /// A live view of the table, filtered by [select].
  ///
  /// The listener is attached *before* the first snapshot is delivered, so
  /// a subscriber never misses the rows that are already there — exactly
  /// like a Firebase `onValue` listener.
  Stream<List<OrderRecord>> watch(List<OrderRecord> Function(List<OrderRecord>) select) {
    final controller = StreamController<List<OrderRecord>>();
    StreamSubscription<List<OrderRecord>>? sub;
    controller.onListen = () {
      sub = _controller.stream.listen(
        (all) {
          if (!controller.isClosed) controller.add(select(all));
        },
        onError: controller.addError,
      );
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(select(all()));
      });
    };
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  /// A live view of a **single** order.
  Stream<OrderRecord?> watchOne(OrderRecord? Function() select) {
    final controller = StreamController<OrderRecord?>();
    StreamSubscription<List<OrderRecord>>? sub;
    controller.onListen = () {
      sub = _controller.stream.listen(
        (_) {
          if (!controller.isClosed) controller.add(select());
        },
        onError: controller.addError,
      );
      scheduleMicrotask(() {
        if (!controller.isClosed) controller.add(select());
      });
    };
    controller.onCancel = () => sub?.cancel();
    return controller.stream;
  }

  Stream<List<OrderRecord>> get stream => _controller.stream;

  String nextId() => 'order-${_nextId++}';

  void dispose() => _controller.close();
}

/// The write side of the orders table (UC-04) plus the courier's view.
class FakeOrdersService implements OrdersService {
  FakeOrdersService(this.store);

  final FakeOrderStore store;

  /// The orders the client wrote, in the order they were written.
  final List<OrderRecord> created = <OrderRecord>[];

  /// The status changes the courier asked for.
  final List<Map<String, String>> statusUpdates = <Map<String, String>>[];

  @override
  Future<OrderRecord> addNewOrder({
    required String clientId,
    required String clientName,
    required String clientEmail,
    required Address address,
    required String paymentMethod,
    required List<ProductCart> products,
    required double amount,
    PriceBreakdown? quote,
    double distanceKm = 0.0,
    String? receiverPhone,
    String? receiverName,
  }) async {
    final now = DateTime.now();
    // The order snapshot keeps the dish name, the price and the size the
    // customer picked — the same fields the Firebase service persists.
    final items = products
        .map(
          (p) => OrderItem(
            productId: p.uidProduct,
            nameProduct: p.nameProduct,
            picture: p.imageProduct,
            price: p.price,
            quantity: p.quantity,
            optionLabel: p.optionLabel,
          ),
        )
        .toList();
    final order = OrderRecord(
      id: store.nextId(),
      clientId: clientId,
      addressId: address.id,
      street: address.street,
      reference: address.reference,
      latitude: address.latitude,
      longitude: address.longitude,
      paymentMethod: paymentMethod,
      amount: amount,
      status: OrderRecord.statusPaidOut,
      products: items,
      createdAt: now,
      clientName: clientName,
      clientEmail: clientEmail,
      receiverPhone: receiverPhone,
      receiverName: receiverName,
      quote: quote,
      distanceKm: distanceKm,
      placedAt: now.millisecondsSinceEpoch,
    );
    store.put(order);
    created.add(order);
    return order;
  }

  @override
  Stream<List<OrderRecord>> watchMyOrders(String clientId) =>
      store.watch(
        (all) => all.where((o) => o.clientId == clientId).toList(),
      );

  @override
  Future<OrderRecord?> getOrder(String id) async => store.byId(id);

  @override
  Stream<OrderRecord?> watchOrder(String id) =>
      store.watchOne(() => store.byId(id));

  @override
  Future<void> cancelOrder(String orderId, {String? reason}) async {
    final order = store.byId(orderId);
    if (order == null) return;
    store.put(order.copyWith(status: OrderRecord.statusCancelled));
  }

  @override
  Future<List<OrderRecord>> getOrdersForDelivery(String deliveryId) async =>
      store.all().where((o) => o.deliveryUserId == deliveryId).toList();

  @override
  Future<List<OrderRecord>> getAvailableOrders() async =>
      store.all().where((o) => o.deliveryUserId.isEmpty).toList();

  @override
  Stream<List<OrderRecord>> watchDeliveryOrders(String deliveryId) =>
      store.watch(
        (all) => all.where((o) => o.deliveryUserId == deliveryId).toList(),
      );

  @override
  Stream<List<OrderRecord>> watchAvailableOrders() => store.watch(
    (all) => all.where((o) => o.deliveryUserId.isEmpty).toList(),
  );

  @override
  Future<void> acceptOrder(
    String orderId,
    String deliveryId, {
    String? deliveryName,
  }) async {
    final order = store.byId(orderId);
    if (order == null) return;
    store.put(
      order
          .copyWith(
            deliveryUserId: deliveryId,
            deliveryUserName: deliveryName,
            status: OrderRecord.statusDispatched,
          )
          .withLifecycleStamp(OrderRecord.statusDispatched),
    );
  }

  @override
  Future<void> rejectOrder(String orderId, String deliveryId) async {}

  @override
  Future<void> updateDeliveryStatus(
    String orderId,
    String newStatus, {
    String? deliveryPhoto,
    bool cashCollected = false,
    int? collectedAmountVnd,
  }) async {
    statusUpdates.add(<String, String>{
      'orderId': orderId,
      'status': newStatus,
    });
    final order = store.byId(orderId);
    if (order == null) return;
    store.put(
      order.copyWith(
        status: newStatus,
        deliveryPhoto: deliveryPhoto ?? order.deliveryPhoto,
        cashCollected: cashCollected || order.cashCollected,
        cashCollectedAt: cashCollected
            ? DateTime.now().millisecondsSinceEpoch
            : order.cashCollectedAt,
        collectedAmountVnd: collectedAmountVnd ?? order.collectedAmountVnd,
      ).withLifecycleStamp(newStatus),
    );
  }
}

/// The restaurant's view of the orders (UC-09).
class FakeAdminOrdersService implements AdminOrdersService {
  FakeAdminOrdersService(this.store);

  final FakeOrderStore store;

  /// The assignments the admin made.
  final List<Map<String, String>> assignments = <Map<String, String>>[];

  /// The status changes the admin made.
  final List<Map<String, String>> statusUpdates = <Map<String, String>>[];

  @override
  Stream<List<OrderRecord>> watchAllOrders() => store.stream;

  @override
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryUserId,
    required String deliveryUserName,
  }) async {
    assignments.add(<String, String>{
      'orderId': orderId,
      'deliveryUserId': deliveryUserId,
      'deliveryUserName': deliveryUserName,
    });
    final order = store.byId(orderId);
    if (order == null) return;
    store.put(
      order
          .copyWith(
            deliveryUserId: deliveryUserId,
            deliveryUserName: deliveryUserName,
            status: OrderRecord.statusDispatched,
          )
          .withLifecycleStamp(OrderRecord.statusDispatched),
    );
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    statusUpdates.add(<String, String>{
      'orderId': orderId,
      'status': status,
    });
    final order = store.byId(orderId);
    if (order == null) return;
    store.put(
      order
          .copyWith(status: status)
          .withLifecycleStamp(status),
    );
  }
}

/// The customer's own read-side view of the orders (UC-05).
class FakeClientOrdersService implements ClientOrdersService {
  FakeClientOrdersService(this.store);

  final FakeOrderStore store;

  @override
  Future<List<OrderRecord>> listOrdersByClient(String clientId) async {
    final mine = store.all().where((o) => o.clientId == clientId).toList();
    mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine;
  }

  @override
  Stream<List<OrderRecord>> watchClientOrders(String clientId) => store.watch(
    (all) {
      final mine = all.where((o) => o.clientId == clientId).toList();
      mine.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return mine;
    },
  );

  @override
  Stream<OrderRecord?> watchOrderUpdates(String orderId) =>
      store.watchOne(() => store.byId(orderId));

  @override
  Future<OrderRecord> cancelOrder({
    required String orderId,
    required String reason,
  }) async {
    final order = store.byId(orderId);
    if (order == null) {
      throw ClientOrdersServiceException('Order not found.');
    }
    final cancelled = order.copyWith(status: ClientOrderStatuses.cancelled);
    store.put(cancelled);
    return cancelled;
  }
}

// ---------------------------------------------------------------------------
// Profile & addresses (UC-06)
// ---------------------------------------------------------------------------

/// An in-memory customer profile.
class FakeClientUserService implements ClientUserService {
  FakeClientUserService({User? user})
    : _user =
          user ??
          User(
            uid: 'uid-2',
            email: 'khach@delicia.com',
            firstName: 'Nguyễn',
            lastName: 'Test',
            phone: '0901234567',
            rolId: 2,
          );

  User _user;

  @override
  Future<User> loadProfile(String uid) async => _user;

  @override
  Future<User> updateProfile(
    String uid, {
    String? firstName,
    String? lastName,
    String? phone,
    String? dateOfBirth,
  }) async {
    _user = _user.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      dateOfBirth: dateOfBirth,
    );
    return _user;
  }

  @override
  Future<User> uploadAvatar(String uid, Uint8List bytes, {String? mime}) async =>
      _user;

  @override
  Future<User> uploadAvatarFile(String uid, File file) async => _user;

  @override
  Stream<User?> watchProfile(String uid) => Stream<User?>.value(_user);

  @override
  Future<Uint8List?> loadAvatarBytes(String uid) async => null;
}

/// An in-memory address book.
class FakeClientAddressService implements ClientAddressService {
  FakeClientAddressService({List<ClientAddress>? seed})
    : _addresses = List<ClientAddress>.from(seed ?? _defaultAddresses);

  static final List<ClientAddress> _defaultAddresses = <ClientAddress>[
    const ClientAddress(
      id: 'addr-1',
      street: '1 Lê Lợi, Bến Nghé',
      reference: 'Quận 1, TP. Hồ Chí Minh',
      latitude: 10.7769,
      longitude: 106.7009,
      isDefault: true,
    ),
  ];

  final List<ClientAddress> _addresses;

  @override
  Future<List<ClientAddress>> listAddresses(String uid) async =>
      List<ClientAddress>.from(_addresses);

  @override
  Stream<List<ClientAddress>> watchAddresses(String uid) =>
      Stream<List<ClientAddress>>.value(List<ClientAddress>.from(_addresses));

  @override
  Future<ClientAddress> addAddress(String uid, ClientAddress address) async {
    final stored = address.copyWith(id: 'addr-${_addresses.length + 1}');
    _addresses.add(stored);
    return stored;
  }

  @override
  Future<ClientAddress> updateAddress(String uid, ClientAddress address) async {
    final index = _addresses.indexWhere((a) => a.id == address.id);
    if (index >= 0) _addresses[index] = address;
    return address;
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async =>
      _addresses.removeWhere((a) => a.id == addressId);

  @override
  Future<void> setDefault(String uid, String addressId) async {
    for (var i = 0; i < _addresses.length; i++) {
      _addresses[i] = _addresses[i].copyWith(
        isDefault: _addresses[i].id == addressId,
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Admin side (UC-07 / UC-09)
// ---------------------------------------------------------------------------

/// The customer list the dashboard counts.
class FakeAdminUsersService implements AdminUsersService {
  FakeAdminUsersService({List<CustomerAccount>? seed})
    : _seed = seed ??
          <CustomerAccount>[
            CustomerAccount(
              uid: 'uid-2',
              name: 'Nguyễn Test',
              email: 'khach@delicia.com',
              createdAt: DateTime.now(),
            ),
          ];

  final List<CustomerAccount> _seed;

  @override
  Stream<List<CustomerAccount>> watchCustomers() =>
      Stream<List<CustomerAccount>>.value(_seed);
}

/// The courier list the admin manages.
class FakeDeliveryUsersService implements DeliveryUsersService {
  FakeDeliveryUsersService({List<DeliveryUser>? seed})
    : _seed = seed ??
          const <DeliveryUser>[
            DeliveryUser(
              uid: 'uid-3',
              name: 'Trần Tài Xế',
              phone: '0909876543',
              email: 'taixe@delicia.com',
            ),
          ];

  final List<DeliveryUser> _seed;

  @override
  Stream<List<DeliveryUser>> watchDeliveryUsers() =>
      Stream<List<DeliveryUser>>.value(_seed);

  @override
  Future<void> setDeliveryEnabled({
    required String uid,
    required bool enabled,
  }) async {}

  @override
  Future<String> createDeliveryDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async => 'uid-new-driver';

  @override
  Future<void> deleteDeliveryDriver({
    required String uid,
    required String email,
  }) async {}
}

// ---------------------------------------------------------------------------
// Realtime map (UC-03)
// ---------------------------------------------------------------------------

/// A realtime transport that never talks to Firebase.
///
/// The map blocs only need *a* stream of positions; the integration test
/// drives them with [publish] instead of a real courier.
class FakeRealtimeService implements RealtimeService {
  FakeRealtimeService();

  final Map<String, StreamController<Map<String, dynamic>>> _controllers =
      <String, StreamController<Map<String, dynamic>>>{};

  /// The positions that were published, per order.
  final Map<String, List<LatLngPayload>> published =
      <String, List<LatLngPayload>>{};

  @override
  Future<void> publishPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    (published[orderId] ??= <LatLngPayload>[]).add(
      LatLngPayload(latitude, longitude),
    );
    _controllers[orderId]?.add(<String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> publishClientPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    _controllers[orderId]?.add(<String, dynamic>{
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  RealtimeSubscription subscribeOrder(String orderId) => _subscribe(orderId);

  @override
  RealtimeSubscription subscribeClientLocation(String orderId) =>
      _subscribe(orderId);

  RealtimeSubscription _subscribe(String orderId) {
    final source = _controllers.putIfAbsent(
      orderId,
      () => StreamController<Map<String, dynamic>>.broadcast(),
    );
    // `RealtimeSubscription` exposes a controller, so the positions are
    // forwarded into it — exactly like the Firebase listener would.
    final controller = StreamController<RealtimePositionUpdate>.broadcast();
    source.stream.listen((raw) {
      if (controller.isClosed) return;
      controller.add(RealtimePositionUpdate.fromMap(orderId, raw));
    });
    return RealtimeSubscription(
      controller: controller,
      cancelRaw: () async {
        if (!controller.isClosed) await controller.close();
      },
    );
  }

  void dispose() {
    for (final c in _controllers.values) {
      c.close();
    }
    _controllers.clear();
  }
}

/// A published position.
class LatLngPayload {
  const LatLngPayload(this.latitude, this.longitude);

  final double latitude;
  final double longitude;
}

/// Stamps the lifecycle moment that [status] represents.
///
/// The production service writes the timestamp together with the status in
/// a single update; the fake does the same through [OrderRecord.copyWith].
extension OrderRecordLifecycle on OrderRecord {
  OrderRecord withLifecycleStamp(String status) {
    final now = DateTime.now().millisecondsSinceEpoch;
    switch (status) {
      case OrderRecord.statusDispatched:
        return copyWith(dispatchedAt: now);
      case OrderRecord.statusOnWay:
      case 'PICKED UP':
        return copyWith(onWayAt: now);
      case OrderRecord.statusDelivered:
        return copyWith(deliveredAt: now);
      default:
        return this;
    }
  }
}
