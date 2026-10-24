import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';

import '../../data/env/environment.dart';
import '../models/user.dart';

/// Errors thrown by [AuthService] (UC-01).
class AuthServiceException implements Exception {
  final String message;
  AuthServiceException(this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase Auth + Realtime Database for the Auth flow.
///
/// All methods are awaited and translate Firebase exceptions into
/// [AuthServiceException] so the BLoC can surface user-friendly errors.
class AuthService {
  AuthService({fb.FirebaseAuth? auth, FirebaseDatabase? database})
      : _auth = auth ?? fb.FirebaseAuth.instance,
        _database = database ??
            FirebaseDatabase.instanceFor(
              app: fb.FirebaseAuth.instance.app,
              databaseURL: Environment.firebaseDatabaseUrl,
            );

  final fb.FirebaseAuth _auth;
  final FirebaseDatabase _database;

  DatabaseReference get _usersRef => _database.ref('users');

  /// Returns the currently signed-in Firebase user (or `null` if none).
  fb.User? get currentFirebaseUser => _auth.currentUser;

  /// Listens to auth state changes. The callback fires whenever the user
  /// signs in, signs out, or the token rotates.
  Stream<fb.User?> get authStateChanges => _auth.authStateChanges();

  /// Loads the user profile from the Realtime Database.
  ///
  /// If the profile is missing (e.g. the user was created before the DB write
  /// succeeded, or was created in a different region), this method
  /// transparently upserts a minimal profile from the FirebaseAuth claims
  /// and returns it.  This makes the auth flow resilient to partial writes.
  Future<User> _loadUserProfile(String uid, {fb.User? fbUser}) async {
    final fbUserResolved = fbUser ?? _auth.currentUser;
    try {
      final snapshot = await _usersRef.child(uid).once();
      final value = snapshot.snapshot.value;
      if (value is Map) {
        final map = Map<dynamic, dynamic>.from(value);
        return User.fromMap({'uid': uid, ...map});
      }
      // Profile missing — fall through to the upsert path.
    } catch (_) {
      // Network/region errors also fall through to the upsert path; the
      // upsert will surface the real error if the DB is still unreachable.
    }
    return _upsertMinimalProfile(uid, fbUserResolved);
  }

  Future<User> _upsertMinimalProfile(String uid, fb.User? fbUser) async {
    final email = fbUser?.email ?? '';
    final displayName = (fbUser?.displayName ?? '').trim();
    final parts =
        displayName.isEmpty ? <String>[] : displayName.split(RegExp(r'\s+'));
    final first = parts.isEmpty ? email : parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final minimal = <String, dynamic>{
      'email': email,
      'firstName': first,
      'lastName': last,
      'phone': fbUser?.phoneNumber ?? '',
      'image': fbUser?.photoURL ?? '',
      'rolId': 2,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await _usersRef.child(uid).update(minimal);
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException(
        'Could not create missing user profile (region/DB error): $e',
      );
    }
    return User.fromMap({'uid': uid, ...minimal});
  }

  /// Sign in with email + password, returns the resolved [User] (incl. role).
  Future<User> login(String email, String password) async {
    fb.UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapAuthError(e));
    } catch (e) {
      throw AuthServiceException('Unexpected login error: $e');
    }
    final fbUser = credential.user;
    if (fbUser == null) {
      throw AuthServiceException('Login failed: no user returned by Firebase');
    }
    return _loadUserProfile(fbUser.uid);
  }

  /// Triggers a password-reset email. The actual navigation is handled by the
  /// UI (push to `/check-email`).
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapAuthError(e));
    } catch (e) {
      throw AuthServiceException('Unexpected forgot-password error: $e');
    }
  }

  /// Creates a new Firebase Auth account, then writes a `users/{uid}` profile
  /// node in the Realtime Database.
  ///
  /// Returns the new [User] (with `rolId` and the assigned Firebase uid).
  /// The default [rolId] is 2 (Client). Pass a different value for Admin/
  /// Delivery sign-up flows (handled in UC-06 / UC-09).
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 2,
  }) async {
    fb.UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw AuthServiceException(_mapAuthError(e));
    } catch (e) {
      throw AuthServiceException('Unexpected register error: $e');
    }

    final fbUser = credential.user;
    if (fbUser == null) {
      throw AuthServiceException(
        'Registration failed: no user returned by Firebase',
      );
    }

    final profile = <String, dynamic>{
      'email': email.trim(),
      'firstName': firstName.trim(),
      'lastName': lastName.trim(),
      'rolId': rolId,
      'phone': phone?.trim() ?? '',
      'image': '',
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await _usersRef.child(fbUser.uid).set(profile);
    } catch (e) {
      // Region / connectivity error on the *write* path.  The Auth account
      // is already created, so we don't fail the whole flow.  Instead we
      // return the constructed User object — the next login will retry the
      // profile write via the lazy-upsert path in `_loadUserProfile`.
      return User(
        uid: fbUser.uid,
        email: profile['email'] as String,
        firstName: profile['firstName'] as String,
        lastName: profile['lastName'] as String,
        phone: profile['phone'] as String,
        image: profile['image'] as String,
        rolId: rolId,
      );
    }

    return User(
      uid: fbUser.uid,
      email: profile['email'] as String,
      firstName: profile['firstName'] as String,
      lastName: profile['lastName'] as String,
      phone: profile['phone'] as String,
      image: profile['image'] as String,
      rolId: rolId,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Re-reads the user profile from the database (used by [CheckLoginEvent]).
  Future<User?> checkLogin() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    try {
      return await _loadUserProfile(fbUser.uid);
    } on AuthServiceException {
      return null;
    }
  }

  String _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'This email is already registered. Try signing in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled. '
            'Enable it in Firebase Console -> Authentication -> Sign-in method.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return e.message ?? 'Authentication error (${e.code})';
    }
  }
}
