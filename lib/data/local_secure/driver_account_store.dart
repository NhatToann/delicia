import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers the Firebase Auth refresh token of every driver account the
/// admin created **on this device**.
///
/// Deleting a driver removes their `users/{uid}` profile, but the
/// Firebase Auth account needs its own token to be deleted as well — and
/// `accounts:delete` only accepts the token of the account being removed.
/// The refresh token is the only credential the admin can hold on to
/// without knowing the driver's password.
///
/// The token is deliberately **not** stored in the Realtime Database: the
/// database is readable without authentication, so a token parked there
/// would be a standing invitation to impersonate the driver. The
/// encrypted shared preferences keep it on the device that created the
/// account, which is also where the admin works.
class DriverAccountStore {
  DriverAccountStore._();
  static final DriverAccountStore instance = DriverAccountStore._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Prefix of the per-driver key.
  static const _prefix = 'driverRefreshToken:';

  String _key(String uid) => '$_prefix$uid';

  /// Stores the refresh token of the driver [uid].
  Future<void> saveRefreshToken(String uid, String refreshToken) {
    return _storage.write(key: _key(uid), value: refreshToken);
  }

  /// Reads the stored refresh token of the driver [uid] (or `null`).
  Future<String?> readRefreshToken(String uid) {
    return _storage.read(key: _key(uid));
  }

  /// Forgets the refresh token of the driver [uid].
  Future<void> deleteRefreshToken(String uid) {
    return _storage.delete(key: _key(uid));
  }
}
