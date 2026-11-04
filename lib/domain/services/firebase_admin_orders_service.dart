import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:http/http.dart' as http;

import '../../data/env/environment.dart';
import '../../data/local_secure/driver_account_store.dart';
import '../models/customer_account.dart';
import '../models/delivery_user.dart';
import '../models/order_record.dart';
import 'admin_orders_service.dart';
import 'app_failure.dart';

/// Firebase Realtime Database backed [AdminOrdersService] (UC-09).
///
/// Unlike the client-facing orders service, this one watches the whole
/// `delicia/orders` node — the restaurant sees every order, not just one
/// customer's.
class FirebaseAdminOrdersService implements AdminOrdersService {
  FirebaseAdminOrdersService({FirebaseDatabase? database})
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

  DatabaseReference? get _ordersRef =>
      _database?.ref('${Environment.dbRoot}/orders');

  @override
  Stream<List<OrderRecord>> watchAllOrders() {
    final ref = _ordersRef;
    if (ref == null) {
      return Stream<List<OrderRecord>>.value(const <OrderRecord>[]);
    }
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <OrderRecord>[];
      final out = <OrderRecord>[];
      value.forEach((key, entry) {
        if (entry is Map) {
          out.add(
            OrderRecord.fromMap(
              key.toString(),
              Map<dynamic, dynamic>.from(entry),
            ),
          );
        }
      });
      // Newest first — the admin works the queue from the top.
      out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return out;
    }).handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }

  @override
  Future<void> assignDelivery({
    required String orderId,
    required String deliveryUserId,
    required String deliveryUserName,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(orderId).update(<String, Object>{
        'deliveryUserId': deliveryUserId,
        'deliveryUserName': deliveryUserName,
        'status': OrderRecord.statusDispatched,
      });
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersAssignDelivery,
        '$e',
      );
    }
  }

  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(orderId).update(<String, Object>{'status': status});
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.ordersUpdateStatus,
        '$e',
      );
    }
  }
}

/// Firebase Realtime Database backed [DeliveryUsersService] (UC-09).
///
/// The delivery drivers live in the shared `users/{uid}` node, told
/// apart by `rolId == 3`. The `enabled` flag is written next to the
/// profile so the admin console can disable a driver without touching
/// Firebase Auth (the account stays, only the dispatch is blocked).
class FirebaseDeliveryUsersService implements DeliveryUsersService {
  FirebaseDeliveryUsersService({
    FirebaseDatabase? database,
    http.Client? httpClient,
  })  : _database = database ?? _defaultDatabase(),
        _http = httpClient ?? http.Client();

  final FirebaseDatabase? _database;

  /// The HTTP client used for the Identity Toolkit calls.
  final http.Client _http;

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

  DatabaseReference? get _usersRef => _database?.ref('users');

  @override
  Stream<List<DeliveryUser>> watchDeliveryUsers() {
    final ref = _usersRef;
    if (ref == null) {
      return Stream<List<DeliveryUser>>.value(const <DeliveryUser>[]);
    }
    // The number of orders a driver is currently carrying is derived from
    // the orders node — it is not stored on the profile, and it has to
    // stay in sync when a driver is dispatched.
    final ordersRef = _database?.ref('${Environment.dbRoot}/orders');
    if (ordersRef == null) {
      return ref.onValue.map((event) => _parseUsers(event));
    }
    return ref.onValue
        .asyncMap((event) async {
          final orders = await ordersRef.once();
          final counts = _activeOrderCounts(orders);
          return _parseUsers(event, activeOrders: counts);
        })
        .handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }

  /// Counts the in-flight orders per driver.
  static Map<String, int> _activeOrderCounts(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) return const <String, int>{};
    final counts = <String, int>{};
    value.forEach((_, entry) {
      if (entry is! Map) return;
      final uid = (entry['deliveryUserId'] ?? '').toString();
      if (uid.isEmpty) return;
      final status = (entry['status'] ?? '').toString();
      if (status == OrderRecord.statusDelivered ||
          status == OrderRecord.statusCancelled) {
        return;
      }
      counts[uid] = (counts[uid] ?? 0) + 1;
    });
    return counts;
  }

  /// Turns a `users/{uid}` snapshot into the driver list.
  static List<DeliveryUser> _parseUsers(
    DatabaseEvent event, {
    Map<String, int> activeOrders = const <String, int>{},
  }) {
    final value = event.snapshot.value;
    if (value is! Map) return const <DeliveryUser>[];
    final out = <DeliveryUser>[];
    value.forEach((key, entry) {
      if (entry is! Map) return;
      if (int.tryParse((entry['rolId'] ?? '').toString()) != 3) return;
      final uid = key.toString();
      out.add(
        DeliveryUser.fromMap(
          uid,
          Map<dynamic, dynamic>.from(entry),
        ).copyWith(activeOrders: activeOrders[uid] ?? 0),
      );
    });
    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  @override
  Future<void> setDeliveryEnabled({
    required String uid,
    required bool enabled,
  }) async {
    final ref = _usersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }
    try {
      await ref.child(uid).update(<String, Object>{'enabled': enabled});
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryToggleEnabled,
        '$e',
      );
    }
  }

  // ---- Creating / deleting a driver ---------------------------------------
  //
  // The Identity Toolkit REST API is used instead of the Firebase Auth
  // client SDK for one reason: `createUserWithEmailAndPassword` on the
  // default app **signs the admin out** and signs the new driver in.
  // The REST endpoint creates the account and returns its uid without
  // touching any local session, so the admin keeps working.
  //
  // A Web API key is not a secret — it ships inside every build of the
  // app anyway (`google-services.json` → `google_api_key`) and only
  // identifies the project.

  /// Identity Toolkit base URL.
  static const String _identityToolkit = 'https://identitytoolkit.googleapis.com';

  /// Token-exchange endpoint used to mint an id token from a refresh
  /// token.
  static const String _secureToken = 'https://securetoken.googleapis.com/v1/token';

  @override
  Future<String> createDeliveryDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
  }) async {
    final ref = _usersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }

    final account = await _signUp(email: email, password: password);

    // The profile is written as a *complete* document — a partial write
    // would wipe fields the auth flow expects (see the RTDB `PATCH`
    // gotcha in AGENTS.md).
    final profile = <String, Object>{
      'email': email.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'phone': phone?.trim() ?? '',
      'image': '',
      'rolId': 3,
      'enabled': true,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await ref.child(account.uid).set(profile);
    } catch (e) {
      // The auth account exists but the profile does not — remove the
      // account so the admin does not end up with an orphaned login.
      await _deleteAuthAccount(account.uid, account.refreshToken);
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryCreate,
        '$e',
      );
    }

    // The refresh token is the only credential that authorises the
    // deletion of this account later on (the admin does not know the
    // driver's password). It is kept in the encrypted local storage —
    // never in the Realtime Database, which is readable without
    // authentication.
    await DriverAccountStore.instance.saveRefreshToken(
      account.uid,
      account.refreshToken,
    );

    return account.uid;
  }

  @override
  Future<void> deleteDeliveryDriver({
    required String uid,
    required String email,
  }) async {
    final ref = _usersRef;
    if (ref == null) {
      throw AdminOrdersServiceException(
        AppFailureCodes.firebaseNotInitialised,
      );
    }

    // Read the refresh token *before* the profile goes away — it is what
    // authorises the deletion of the auth account.
    final refreshToken = await DriverAccountStore.instance.readRefreshToken(uid);

    try {
      await ref.child(uid).remove();
    } catch (e) {
      if (e is AdminOrdersServiceException) rethrow;
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryDelete,
        '$e',
      );
    }

    await DriverAccountStore.instance.deleteRefreshToken(uid);

    try {
      await _deleteAuthAccount(uid, refreshToken);
    } catch (_) {
      // The driver is already out of the system. A surviving auth
      // account only means the person can still log in — without a
      // profile the login flow has no role to give them, so it is
      // harmless.
    }
  }

  /// Creates a Firebase Auth account without touching the local session.
  Future<_DriverAccount> _signUp({
    required String email,
    required String password,
  }) async {
    final uri = Uri.parse(
      '$_identityToolkit/v1/accounts:signUp?key=${Environment.firebaseApiKey}',
    );
    late final http.Response response;
    try {
      response = await _http
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
            },
            body: jsonEncode(<String, Object>{
              'email': email.trim(),
              'password': password,
              'returnSecureToken': true,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryCreate,
        '$e',
      );
    }

    if (response.statusCode != 200) {
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryCreate,
        _identityErrorText(response),
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final uid = (body['localId'] ?? '').toString();
    if (uid.isEmpty) {
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryCreate,
        'no user id',
      );
    }
    return _DriverAccount(
      uid: uid,
      refreshToken: (body['refreshToken'] ?? '').toString(),
    );
  }

  /// Deletes the Firebase Auth account of a driver.
  ///
  /// `accounts:delete` removes the account the id token belongs to, so
  /// the driver's own token is minted from the stored refresh token
  /// first. The admin's token is never sent, so the admin session can
  /// not be affected.
  Future<void> _deleteAuthAccount(String uid, String? refreshToken) async {
    if (refreshToken == null || refreshToken.isEmpty) return;

    final idToken = await _mintIdToken(refreshToken);
    if (idToken.isEmpty) return;

    final uri = Uri.parse(
      '$_identityToolkit/v1/accounts:delete?key=${Environment.firebaseApiKey}',
    );
    final response = await _http
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, Object>{'idToken': idToken}),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw AdminOrdersServiceException(
        AppFailureCodes.deliveryDelete,
        _identityErrorText(response),
      );
    }
  }

  /// Exchanges a refresh token for a short-lived id token.
  Future<String> _mintIdToken(String refreshToken) async {
    final uri = Uri.parse('$_secureToken?key=${Environment.firebaseApiKey}');
    final response = await _http
        .post(
          uri,
          headers: const <String, String>{
            'Content-Type': 'application/json',
          },
          body: jsonEncode(<String, Object>{
            'grant_type': 'refresh_token',
            'refresh_token': refreshToken,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) return '';
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return (body['id_token'] ?? '').toString();
  }

  /// Extracts a readable message out of an Identity Toolkit error body.
  static String _identityErrorText(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final error = body['error'];
      if (error is Map) {
        final message = (error['message'] ?? '').toString();
        if (message.isNotEmpty) return message;
      }
    } catch (_) {
      // Fall through to the raw status code.
    }
    return 'HTTP ${response.statusCode}';
  }
}

/// The account returned by `accounts:signUp`.
class _DriverAccount {
  const _DriverAccount({required this.uid, required this.refreshToken});

  /// The Firebase uid of the new account.
  final String uid;

  /// The refresh token — kept in the encrypted local storage so the
  /// account can be deleted later.
  final String refreshToken;
}

/// Firebase Realtime Database backed [AdminUsersService] (UC-07).
///
/// The customers live in the shared `users/{uid}` node, told apart by
/// `rolId == 2`.
class FirebaseAdminUsersService implements AdminUsersService {
  FirebaseAdminUsersService({FirebaseDatabase? database})
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

  DatabaseReference? get _usersRef => _database?.ref('users');

  @override
  Stream<List<CustomerAccount>> watchCustomers() {
    final ref = _usersRef;
    if (ref == null) {
      return Stream<List<CustomerAccount>>.value(const <CustomerAccount>[]);
    }
    return ref.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return const <CustomerAccount>[];
      final out = <CustomerAccount>[];
      value.forEach((key, entry) {
        if (entry is! Map) return;
        if (int.tryParse((entry['rolId'] ?? '').toString()) != 2) return;
        out.add(
          CustomerAccount.fromMap(
            key.toString(),
            Map<dynamic, dynamic>.from(entry),
          ),
        );
      });
      return out;
    }).handleError((Object e) {
      throw AdminOrdersServiceException(AppFailureCodes.ordersWatch, '$e');
    });
  }
}
