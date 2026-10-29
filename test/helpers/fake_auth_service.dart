// Fake [AuthService] used by every test that wants an `AuthBloc` without
// hitting Firebase. Mirrors the contract in `lib/domain/services/auth_service.dart`,
// returning whatever [user] is supplied (or a built-in default) and
// optionally throwing on `login` / `forgotPassword` / `register` so the
// failure paths can be exercised too.

import 'dart:typed_data';

import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/app_failure.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class FakeAuthService implements AuthService {
  FakeAuthService({this.shouldThrow = false, this.user});

  bool shouldThrow;
  User? user;

  @override
  Future<User> login(String email, String password) async {
    if (shouldThrow) {
      throw const AuthServiceException(AppFailureCodes.authInvalidCredentials);
    }
    return user ??
        User(
          uid: 'u1',
          email: email,
          firstName: 'Test',
          lastName: 'User',
          rolId: 2,
        );
  }

  @override
  Future<User?> checkLogin() async {
    return user;
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
    image: profileImageBytes == null ? null : 'profile-image-uploaded',
  );

  @override
  @override
  Stream<fb.User?> get authStateChanges => const Stream<fb.User?>.empty();
  @override
  fb.User? get currentFirebaseUser => null;

  @override
  Future<void> forgotPassword(String email) async {
    if (shouldThrow) {
      throw const AuthServiceException(AppFailureCodes.authLoginNoUser);
    }
  }

  @override
  Future<void> logout() async {}

  @override
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 2,
  }) async {
    if (shouldThrow) {
      throw const AuthServiceException(AppFailureCodes.authEmailInUse);
    }
    return User(
      uid: 'u-new',
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      rolId: rolId,
    );
  }
}
