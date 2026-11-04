import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:firebase_database/firebase_database.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../data/env/environment.dart';
import '../models/user.dart';
import 'app_failure.dart';

/// Errors thrown by [AuthService] (UC-01).
///
/// The exception carries a stable failure *code* from [AppFailureCodes];
/// the presentation layer turns that code into Vietnamese copy.
class AuthServiceException extends AppFailure {
  const AuthServiceException(super.code, [super.detail]);
}

/// Wraps Firebase Auth + Realtime Database for the Auth flow.
///
/// All methods are awaited and translate Firebase exceptions into
/// [AuthServiceException] so the BLoC can surface user-friendly errors.
class AuthService {
  static const int _maxProfileImageBytes = 1024 * 1024;

  AuthService({fb.FirebaseAuth? auth, FirebaseDatabase? database})
    : _auth = auth ?? fb.FirebaseAuth.instance,
      _database =
          database ??
          FirebaseDatabase.instanceFor(
            app: fb.FirebaseAuth.instance.app,
            databaseURL: Environment.firebaseDatabaseUrl,
          );

  final fb.FirebaseAuth _auth;
  final FirebaseDatabase _database;

  DatabaseReference get _usersRef => _database.ref('users');

  /// The Google Sign-In manager.
  ///
  /// `google_sign_in` requires a one-off [GoogleSignIn.initialize] before
  /// any other call. The plugin reads the `serverClientId` it needs from
  /// `google-services.json` (the web OAuth client, `client_type: 3`), so
  /// the Firebase Console's "Add app → Web" step has to be done — it is
  /// what puts that entry in the file.
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  /// Prepares the Google Sign-In manager.
  ///
  /// Safe to call repeatedly: the plugin only needs to be initialized
  /// once per process, and the second call is a no-op.
  Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) return;
    try {
      await _googleSignIn.initialize();
      _googleInitialized = true;
    } catch (e) {
      throw AuthServiceException(
        AppFailureCodes.authGoogleUnavailable,
        '$e',
      );
    }
  }

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
    final parts = displayName.isEmpty
        ? <String>[]
        : displayName.split(RegExp(r'\s+'));
    final first = parts.isEmpty ? email : parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final minimal = <String, dynamic>{
      'email': email,
      'firstName': first,
      'lastName': last,
      'phone': fbUser?.phoneNumber ?? '',
      'image': fbUser?.photoURL ?? '',
      'rolId': 1,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
    try {
      await _usersRef.child(uid).update(minimal);
    } on AuthServiceException {
      rethrow;
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authProfileCreate, '$e');
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
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authUnexpectedLogin, '$e');
    }
    final fbUser = credential.user;
    if (fbUser == null) {
      throw const AuthServiceException(AppFailureCodes.authLoginNoUser);
    }
    return _loadUserProfile(fbUser.uid);
  }

  /// Signs in with a Google account and returns the resolved [User].
  ///
  /// The flow is the standard three steps:
  ///   1. `google_sign_in` shows the account picker and hands back an
  ///      OIDC **ID token**;
  ///   2. that token is exchanged for a Firebase session with
  ///      [fb.GoogleAuthProvider];
  ///   3. the Realtime Database profile is read (or created) for the
  ///      resulting user, exactly like the email/password path.
  ///
  /// A Google account that has never used Delicia before is a *new* user:
  /// Firebase creates the account on the fly and [rolId] defaults to
  /// 1 (Client), which the role picker then confirms.
  Future<User> loginWithGoogle() async {
    await _ensureGoogleInitialized();

    GoogleSignInAccount googleAccount;
    try {
      googleAccount = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      throw _mapGoogleError(e);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authGoogleFailed, '$e');
    }

    final idToken = googleAccount.authentication.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw const AuthServiceException(AppFailureCodes.authGoogleNoToken);
    }

    fb.UserCredential credential;
    try {
      final googleCredential = fb.GoogleAuthProvider.credential(idToken: idToken);
      credential = await _auth.signInWithCredential(googleCredential);
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authGoogleFailed, '$e');
    }

    final fbUser = credential.user;
    if (fbUser == null) {
      throw const AuthServiceException(AppFailureCodes.authGoogleNoUser);
    }

    // Keep the Google display name and avatar on the profile so the app
    // shows the customer's real name instead of a blank form.
    final displayName = googleAccount.displayName;
    final photoUrl = googleAccount.photoUrl;
    if (displayName != null || photoUrl != null) {
      try {
        final parts = (displayName ?? '').trim().split(
          RegExp(r'\s+'),
        );
        final first = parts.isEmpty ? fbUser.email : parts.first;
        final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
        await _usersRef.child(fbUser.uid).update(<String, Object?>{
          'firstName': first,
          'lastName': last,
          if (photoUrl != null) 'image': photoUrl,
        });
      } catch (_) {
        // A failed profile refresh must not break the sign-in — the
        // lazy-upsert path in `_loadUserProfile` fills the gap later.
      }
    }

    return _loadUserProfile(fbUser.uid);
  }

  /// Triggers a password-reset email. The actual navigation is handled by the
  /// UI (push to `/check-email`).
  Future<void> forgotPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authUnexpectedForgot, '$e');
    }
  }

  /// Creates a new Firebase Auth account, then writes a `users/{uid}` profile
  /// node in the Realtime Database.
  ///
  /// Returns the new [User] (with `rolId` and the assigned Firebase uid).
  /// The default [rolId] is 1 (Client). Pass a different value for Admin/
  /// Delivery sign-up flows (handled in UC-06 / UC-09).
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 1,
  }) async {
    fb.UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb.FirebaseAuthException catch (e) {
      throw _mapAuthError(e);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authUnexpectedRegister, '$e');
    }

    final fbUser = credential.user;
    if (fbUser == null) {
      throw const AuthServiceException(AppFailureCodes.authRegisterNoUser);
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
      dateOfBirth: profile['dateOfBirth'] as String?,
      rolId: rolId,
    );
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Updates editable profile fields in `users/{uid}` and returns the new
  /// in-memory profile. Email remains managed by Firebase Auth separately.
  Future<User> updateProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String phone,
    required String dateOfBirth,
    Uint8List? profileImageBytes,
    String? profileImageContentType,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.uid != user.uid) {
      throw const AuthServiceException(AppFailureCodes.authProfileUpdate);
    }

    final normalizedFirstName = firstName.trim();
    final normalizedLastName = lastName.trim();
    final normalizedPhone = phone.replaceAll(RegExp(r'[\s().-]'), '');
    if (!_isValidProfileData(
      firstName: normalizedFirstName,
      lastName: normalizedLastName,
      email: user.email.trim(),
      phone: normalizedPhone,
      dateOfBirth: dateOfBirth,
    )) {
      throw const AuthServiceException(AppFailureCodes.authProfileUpdate);
    }

    final changes = <String, Object?>{
      'firstName': normalizedFirstName,
      'lastName': normalizedLastName,
      'phone': normalizedPhone,
      'dateOfBirth': dateOfBirth,
    };

    String? imageUrl;
    if (profileImageBytes != null) {
      final contentType = profileImageContentType;
      if (profileImageBytes.isEmpty ||
          profileImageBytes.length > _maxProfileImageBytes ||
          !_hasSupportedImageSignature(profileImageBytes, contentType)) {
        throw const AuthServiceException(AppFailureCodes.authProfileUpdate);
      }

      imageUrl = 'data:$contentType;base64,${base64Encode(profileImageBytes)}';
      changes['image'] = imageUrl;
    }

    try {
      await _usersRef.child(user.uid).update(changes);
    } catch (e) {
      throw AuthServiceException(AppFailureCodes.authProfileUpdate, '$e');
    }

    return user.copyWith(
      firstName: firstName.trim(),
      lastName: normalizedLastName,
      phone: normalizedPhone,
      dateOfBirth: dateOfBirth,
      image: imageUrl,
    );
  }

  static bool _isValidProfileData({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String dateOfBirth,
  }) {
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part.isNotEmpty).join(' ');
    final namePattern = RegExp(r"^[A-Za-zÀ-ỹ]+(?:[ '-][A-Za-zÀ-ỹ]+)*$");
    final emailPattern = RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    );
    final phonePattern = RegExp(r'^(?:0\d{8,10}|\+?[1-9]\d{7,14})$');
    final birthDate = DateTime.tryParse(dateOfBirth);

    return fullName.length >= 2 &&
        firstName.isNotEmpty &&
        namePattern.hasMatch(fullName) &&
        emailPattern.hasMatch(email) &&
        phonePattern.hasMatch(phone) &&
        birthDate != null &&
        birthDate.year >= 1900 &&
        !birthDate.isAfter(DateTime.now()) &&
        birthDate.toIso8601String().split('T').first == dateOfBirth;
  }

  static bool _hasSupportedImageSignature(
    Uint8List bytes,
    String? contentType,
  ) {
    switch (contentType) {
      case 'image/jpeg':
        return bytes.length >= 3 &&
            bytes[0] == 0xff &&
            bytes[1] == 0xd8 &&
            bytes[2] == 0xff;
      case 'image/png':
        const signature = <int>[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a];
        if (bytes.length < signature.length) return false;
        for (var i = 0; i < signature.length; i++) {
          if (bytes[i] != signature[i]) return false;
        }
        return true;
      case 'image/webp':
        return bytes.length >= 12 &&
            String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
            String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      default:
        return false;
    }
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

  /// Maps a Firebase Auth error code onto one of our own failure codes.
  ///
  /// The wording lives in the translation table, so this method only has to
  /// decide *what* went wrong, never how to say it.
  AuthServiceException _mapAuthError(fb.FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return const AuthServiceException(
          AppFailureCodes.authInvalidCredentials,
        );
      case 'email-already-in-use':
        return const AuthServiceException(AppFailureCodes.authEmailInUse);
      case 'weak-password':
        return const AuthServiceException(AppFailureCodes.authWeakPassword);
      case 'operation-not-allowed':
        return const AuthServiceException(AppFailureCodes.authProviderDisabled);
      case 'user-disabled':
        return const AuthServiceException(AppFailureCodes.authAccountDisabled);
      case 'too-many-requests':
        return const AuthServiceException(AppFailureCodes.authTooManyRequests);
      case 'invalid-email':
        return const AuthServiceException(AppFailureCodes.authInvalidEmail);
      case 'network-request-failed':
        return const AuthServiceException(AppFailureCodes.authNetwork);
      default:
        return AuthServiceException(AppFailureCodes.authUnknown, e.code);
    }
  }

  /// Maps a `google_sign_in` failure onto one of our own failure codes.
  ///
  /// The wording lives in the translation table, so this method only has to
  /// decide *what* went wrong, never how to say it.
  AuthServiceException _mapGoogleError(GoogleSignInException e) {
    switch (e.code) {
      case GoogleSignInExceptionCode.canceled:
        return const AuthServiceException(AppFailureCodes.authGoogleCanceled);
      case GoogleSignInExceptionCode.interrupted:
        return const AuthServiceException(AppFailureCodes.authGoogleFailed);
      case GoogleSignInExceptionCode.uiUnavailable:
        return const AuthServiceException(AppFailureCodes.authGoogleUnavailable);
      case GoogleSignInExceptionCode.clientConfigurationError:
        return const AuthServiceException(
          AppFailureCodes.authGoogleMisconfigured,
        );
      case GoogleSignInExceptionCode.providerConfigurationError:
        return const AuthServiceException(
          AppFailureCodes.authGoogleMisconfigured,
        );
      case GoogleSignInExceptionCode.userMismatch:
        return const AuthServiceException(AppFailureCodes.authGoogleFailed);
      case GoogleSignInExceptionCode.unknownError:
        return const AuthServiceException(AppFailureCodes.authGoogleFailed);
    }
  }
}
