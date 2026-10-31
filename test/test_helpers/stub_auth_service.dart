// Test-only helpers shared across the UC-05 / UC-06 widget tests.
// All implementations are hermetic — no Firebase calls.

import 'dart:async';
import 'dart:typed_data';

import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

/// Minimal [AuthService] double — exposes a logged-in user without hitting
/// Firebase. Pass a [User] to the constructor to simulate a logged-in
/// session, or use [loggedIn] for a pre-built default user.
class StubAuthService implements AuthService {
  StubAuthService([User? user])
    : currentUser =
          user ??
          User(
            uid: 'user-1',
            email: 'test@test.com',
            firstName: 'Test',
            lastName: 'User',
            rolId: 2,
          );

  /// User returned by [checkLogin] and exposed via [authStateChanges].
  final User currentUser;

  /// Factory that returns a stub pre-configured with a logged-in user.
  /// Convenience so tests don't have to construct the User manually.
  factory StubAuthService.loggedIn({
    String uid = 'user-1',
    String email = 'test@test.com',
    String firstName = 'Test',
    String lastName = 'User',
  }) => StubAuthService(
    User(
      uid: uid,
      email: email,
      firstName: firstName,
      lastName: lastName,
      rolId: 2,
    ),
  );

  @override
  Future<User> login(String email, String password) async =>
      throw UnimplementedError();

  @override
  Future<void> forgotPassword(String email) async {}

  @override
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 2,
  }) async => throw UnimplementedError();

  @override
  Future<void> logout() async {}

  @override
  Future<User?> checkLogin() async => currentUser;

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

  @override
  fb.User? get currentFirebaseUser => null;

  @override
  Stream<fb.User?> get authStateChanges {
    final ctrl = StreamController<fb.User?>.broadcast();
    // Emit synchronously so the auth-bloc's initial listener picks it up.
    ctrl.add(null);
    ctrl.close();
    return ctrl.stream;
  }
}
