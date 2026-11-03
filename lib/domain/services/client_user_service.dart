import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart' as fs;
import 'package:flutter/foundation.dart';

import '../../../data/env/environment.dart';
import '../models/user.dart';
import 'client_db_paths.dart';

/// Errors thrown by [ClientUserService] (UC-06).
class ClientUserServiceException implements Exception {
  final String message;
  ClientUserServiceException(this.message);
  @override
  String toString() => message;
}

/// Abstract user-profile service used by `UserBloc` (UC-06).
abstract class ClientUserService {
  Future<User> loadProfile(String uid);
  Future<User> updateProfile(
      String uid, {
        String? firstName,
        String? lastName,
        String? phone,
        String? dateOfBirth,
      });
  Future<User> uploadAvatar(String uid, Uint8List bytes, {String? mime});
  Future<User> uploadAvatarFile(String uid, File file);
  Stream<User?> watchProfile(String uid);
  Future<Uint8List?> loadAvatarBytes(String uid);
}

/// Firebase backed [ClientUserService].
class FirebaseClientUserService implements ClientUserService {
  FirebaseClientUserService({FirebaseDatabase? database, fs.FirebaseStorage? storage})
      : _database = database ?? _defaultDatabase(),
        _storage = storage ?? _defaultStorage();

  final FirebaseDatabase? _database;
  final fs.FirebaseStorage? _storage;

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

  static fs.FirebaseStorage? _defaultStorage() {
    try {
      return fs.FirebaseStorage.instanceFor(app: Firebase.app());
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? _userRef(String uid) =>
      _database?.ref('${ClientDbPaths.usersRoot}/$uid');

  @override
  Future<User> loadProfile(String uid) async {
    if (uid.isEmpty) {
      throw ClientUserServiceException('Not signed in.');
    }
    final ref = _userRef(uid);
    if (ref == null) {
      throw ClientUserServiceException(
        'Firebase Database not initialized.',
      );
    }
    try {
      final snap = await ref.once();
      final value = snap.snapshot.value;
      if (value is! Map) {
        throw ClientUserServiceException(
          'Profile not found in database — please sign out and in again.',
        );
      }
      final map = Map<dynamic, dynamic>.from(value);
      return User.fromMap({'uid': uid, ...map});
    } on ClientUserServiceException {
      rethrow;
    } catch (e) {
      throw ClientUserServiceException('Failed to load profile: $e');
    }
  }

  @override
  Future<User> updateProfile(
      String uid, {
        String? firstName,
        String? lastName,
        String? phone,
        String? dateOfBirth,
      }) async {
    if (uid.isEmpty) {
      throw ClientUserServiceException('Not signed in.');
    }
    final ref = _userRef(uid);
    if (ref == null) {
      throw ClientUserServiceException('Firebase Database not initialized.');
    }
    final updates = <String, dynamic>{};
    if (firstName != null) updates['firstName'] = firstName.trim();
    if (lastName != null) updates['lastName'] = lastName.trim();
    if (phone != null) updates['phone'] = phone.trim();
    if (dateOfBirth != null) updates['dateOfBirth'] = dateOfBirth.trim(); // <--- THÊM DÒNG NÀY ĐỂ LƯU NGÀY SINH

    if (updates.isEmpty) {
      return loadProfile(uid);
    }
    updates['updatedAt'] = ServerValue.timestamp;
    try {
      await ref.update(updates);
      return await loadProfile(uid);
    } catch (e) {
      throw ClientUserServiceException('Failed to update profile: $e');
    }
  }

  @override
  Future<User> uploadAvatar(String uid, Uint8List bytes, {String? mime}) async {
    if (uid.isEmpty) {
      throw ClientUserServiceException('Not signed in.');
    }
    if (bytes.isEmpty) {
      throw ClientUserServiceException('Avatar file is empty.');
    }
    final storage = _storage;
    if (storage == null) {
      return _uploadAvatarToDatabase(uid, bytes);
    }
    try {
      final ref = storage
          .ref()
          .child(ClientDbPaths.avatarsRoot)
          .child('$uid.jpg');
      final metadata = fs.SettableMetadata(contentType: mime ?? 'image/jpeg');
      await ref.putData(bytes, metadata);
      final url = await ref.getDownloadURL();
      final userRef = _userRef(uid);
      if (userRef != null) {
        await userRef.update({
          'image': url,
          'updatedAt': ServerValue.timestamp,
        });
      }
      return await loadProfile(uid);
    } catch (e) {
      // Bắt mọi lỗi liên quan đến bucket không tồn tại, object-not-found hoặc network để fallback an toàn
      if (_isBucketMissingOrNotFound(e)) {
        return _uploadAvatarToDatabase(uid, bytes);
      }
      throw ClientUserServiceException('Failed to upload avatar: $e');
    }
  }

  bool _isBucketMissingOrNotFound(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('bucket') ||
        text.contains('storage') ||
        text.contains('404') ||
        text.contains('not found') ||
        text.contains('does not exist') ||
        text.contains('object-not-found') ||
        text.contains('failed host lookup') ||
        text.contains('socketexception');
  }

  Future<User> _uploadAvatarToDatabase(String uid, Uint8List bytes) async {
    final userRef = _userRef(uid);
    if (userRef == null) {
      throw ClientUserServiceException('Firebase Database not initialized.');
    }
    try {
      await userRef.update({
        'avatar': base64Encode(bytes),
        'updatedAt': ServerValue.timestamp,
      });
      return await loadProfile(uid);
    } catch (e) {
      throw ClientUserServiceException('Failed to upload avatar: $e');
    }
  }

  @override
  Future<Uint8List?> loadAvatarBytes(String uid) async {
    final userRef = _userRef(uid);
    if (userRef == null) return null;
    try {
      final snap = await userRef.child('avatar').once();
      final value = snap.snapshot.value;
      if (value is String && value.isNotEmpty) {
        return base64Decode(value);
      }
    } catch (_) {}

    final storage = _storage;
    if (storage == null) return null;
    try {
      final ref = storage
          .ref()
          .child(ClientDbPaths.avatarsRoot)
          .child('$uid.jpg');
      return await ref.getData();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<User> uploadAvatarFile(String uid, File file) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadAvatar(uid, bytes);
    } on ClientUserServiceException {
      rethrow;
    } catch (e) {
      throw ClientUserServiceException('Failed to read avatar file: $e');
    }
  }

  @override
  Stream<User?> watchProfile(String uid) {
    final ref = _userRef(uid);
    if (ref == null) return Stream<User?>.value(null);
    return ref.onValue
        .map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return null;
      try {
        return User.fromMap({
          'uid': uid,
          ...Map<dynamic, dynamic>.from(value),
        });
      } catch (_) {
        return null;
      }
    })
        .handleError((Object e) {
      if (kDebugMode) {
        debugPrint('ClientUserService.watchProfile error: $e');
      }
    });
  }
}