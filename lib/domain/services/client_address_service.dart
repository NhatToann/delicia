import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../../data/env/environment.dart';
import '../models/client_address.dart';
import 'client_db_paths.dart';

/// Errors thrown by [ClientAddressService].
class ClientAddressServiceException implements Exception {
  final String message;
  ClientAddressServiceException(this.message);
  @override
  String toString() => message;
}

/// Address CRUD contract used by `AddressBloc` (UC-06).
///
/// Every method is scoped to a single UID **by construction** — a caller
/// physically cannot read or mutate another user's addresses because the
/// uid is a required argument and it is used to build the database path.
abstract class ClientAddressService {
  /// Loads every saved address for the given user.
  ///
  /// Implementations must return an empty list (not throw) when the user
  /// has no saved addresses yet.
  Future<List<ClientAddress>> listAddresses(String uid);

  /// Streams the user's addresses so CRUD operations performed on any
  /// screen flow through to the rest of the app.
  Stream<List<ClientAddress>> watchAddresses(String uid);

  /// Persists a new address and returns the stored record (with the
  /// assigned database id).
  Future<ClientAddress> addAddress(String uid, ClientAddress address);

  /// Overwrites an existing address.
  Future<ClientAddress> updateAddress(String uid, ClientAddress address);

  /// Removes the address from the database.
  Future<void> deleteAddress(String uid, String addressId);

  /// Marks [addressId] as the user's default.  Implementations must also
  /// clear the previous default so exactly one address is active.
  Future<void> setDefault(String uid, String addressId);
}

/// Firebase Realtime Database backed [ClientAddressService] for UC-06.
///
/// Schema (per user):
///   `users/{uid}/addresses/{addressId}` → { street, reference,
///                                          latitude, longitude,
///                                          isDefault }
///
/// The `users/{uid}` prefix matches the node UC-01 writes the profile
/// to, so the address list is nested inside the same profile document.
class FirebaseClientAddressService implements ClientAddressService {
  FirebaseClientAddressService({FirebaseDatabase? database})
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

  DatabaseReference? _userAddressesRef(String uid) {
    if (uid.isEmpty) return null;
    final db = _database;
    if (db == null) return null;
    return db.ref(
      '${ClientDbPaths.usersRoot}/$uid/${ClientDbPaths.addressesRoot}',
    );
  }

  DatabaseReference? _userRef(String uid) {
    if (uid.isEmpty) return null;
    final db = _database;
    if (db == null) return null;
    return db.ref('${ClientDbPaths.usersRoot}/$uid');
  }

  @override
  Future<List<ClientAddress>> listAddresses(String uid) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) return const [];
    try {
      final snap = await ref.once();
      return _parse(snap.snapshot.value);
    } on ClientAddressServiceException {
      rethrow;
    } catch (e) {
      throw ClientAddressServiceException('Failed to load addresses: $e');
    }
  }

  @override
  Stream<List<ClientAddress>> watchAddresses(String uid) {
    final ref = _userAddressesRef(uid);
    if (ref == null) return Stream<List<ClientAddress>>.value(const []);
    final controller = StreamController<List<ClientAddress>>.broadcast();
    StreamSubscription<DatabaseEvent>? sub;
    try {
      sub = ref.onValue.listen(
        (event) {
          if (controller.isClosed) return;
          controller.add(_parse(event.snapshot.value));
        },
        onError: controller.addError,
        cancelOnError: false,
      );
    } catch (e) {
      controller.addError(
        ClientAddressServiceException('Watch failed: $e'),
      );
    }
    controller.onCancel = () async {
      await sub?.cancel();
    };
    return controller.stream;
  }

  @override
  Future<ClientAddress> addAddress(
    String uid,
    ClientAddress address,
  ) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) {
      throw ClientAddressServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    if (address.street.trim().isEmpty) {
      throw ClientAddressServiceException('Street is required.');
    }
    try {
      final newRef = ref.push();
      final id = newRef.key;
      if (id == null) {
        throw ClientAddressServiceException('Failed to generate address id.');
      }
      final stored = ClientAddress(
        id: id,
        street: address.street.trim(),
        reference: address.reference.trim(),
        latitude: address.latitude,
        longitude: address.longitude,
        isDefault: address.isDefault ?? false,
      );
      await newRef.set(stored.toMap());
      if (stored.isDefault == true) {
        await _clearOtherDefaults(uid, id);
      }
      // Ensure the user node exists so the schema stays consistent.
      await _userRef(uid)
          ?.child('addressesUpdatedAt')
          .set(ServerValue.timestamp);
      return stored;
    } on ClientAddressServiceException {
      rethrow;
    } catch (e) {
      throw ClientAddressServiceException('Failed to add address: $e');
    }
  }

  @override
  Future<ClientAddress> updateAddress(
    String uid,
    ClientAddress address,
  ) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) {
      throw ClientAddressServiceException(
        'Firebase Database not initialized.',
      );
    }
    if (address.id.isEmpty) {
      throw ClientAddressServiceException('Address id is required.');
    }
    try {
      await ref.child(address.id).update(address.toMap());
      if (address.isDefault == true) {
        await _clearOtherDefaults(uid, address.id);
      }
      return address;
    } on ClientAddressServiceException {
      rethrow;
    } catch (e) {
      throw ClientAddressServiceException('Failed to update address: $e');
    }
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) {
      throw ClientAddressServiceException(
        'Firebase Database not initialized.',
      );
    }
    if (addressId.isEmpty) return;
    try {
      await ref.child(addressId).remove();
    } catch (e) {
      throw ClientAddressServiceException('Failed to delete address: $e');
    }
  }

  @override
  Future<void> setDefault(String uid, String addressId) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) {
      throw ClientAddressServiceException(
        'Firebase Database not initialized.',
      );
    }
    if (addressId.isEmpty) return;
    try {
      // Mark all entries in one round trip.
      final snap = await ref.once();
      final value = snap.snapshot.value;
      if (value is! Map) return;
      final updates = <String, dynamic>{};
      value.forEach((key, val) {
        if (val is! Map) return;
        final id = key.toString();
        updates['$id/isDefault'] = id == addressId;
      });
      if (updates.isNotEmpty) {
        await ref.update(updates);
      }
    } catch (e) {
      throw ClientAddressServiceException(
        'Failed to set default address: $e',
      );
    }
  }

  /// Makes sure at most one address carries the default flag.
  Future<void> _clearOtherDefaults(String uid, String keepId) async {
    final ref = _userAddressesRef(uid);
    if (ref == null) return;
    final snap = await ref.once();
    final value = snap.snapshot.value;
    if (value is! Map) return;
    final updates = <String, dynamic>{};
    value.forEach((key, val) {
      final id = key.toString();
      if (id == keepId) return;
      if (val is! Map) return;
      final isDefault = val['isDefault'];
      if (isDefault == true || isDefault == 'true') {
        updates['$id/isDefault'] = false;
      }
    });
    if (updates.isNotEmpty) {
      await ref.update(updates);
    }
  }

  /// Tolerant parser — malformed rows are skipped rather than failing the
  /// whole list.
  List<ClientAddress> _parse(dynamic raw) {
    final out = <ClientAddress>[];
    if (raw is! Map) return out;
    raw.forEach((key, value) {
      if (value is! Map) return;
      final id = key.toString();
      try {
        out.add(
          ClientAddress.fromMap(id, Map<dynamic, dynamic>.from(value)),
        );
      } catch (_) {
        // skip malformed
      }
    });
    out.sort((a, b) {
      // Default address first.
      if (a.isDefault == true && b.isDefault != true) return -1;
      if (b.isDefault == true && a.isDefault != true) return 1;
      return a.street.compareTo(b.street);
    });
    return out;
  }
}
