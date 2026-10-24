import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Thin wrapper around [FlutterSecureStorage] for persisting the auth token
/// and the active user id.
class SecureStorageFrave {
  SecureStorageFrave._();
  static final SecureStorageFrave instance = SecureStorageFrave._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kToken = 'token';
  static const _kUserId = 'userId';

  Future<void> persistenToken(String token, String userId) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUserId, value: userId);
  }

  Future<String?> readToken() => _storage.read(key: _kToken);
  Future<String?> readUserId() => _storage.read(key: _kUserId);

  Future<void> deleteSecureStorage() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUserId);
  }
}
