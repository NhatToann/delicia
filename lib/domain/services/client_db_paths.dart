/// Database paths used by the UC-06 profile / address feature.
///
/// These are kept in their own file (instead of `Environment`) because
/// `lib/data/env/environment.dart` is a **shared** file that the Leader
/// merges — touching it for a Member-A-only concern guarantees a merge
/// conflict.
///
/// The values must match what UC-01 (`AuthService`) writes:
///   * profiles  → `users/{uid}`
///   * addresses → `users/{uid}/addresses/{addressId}`
class ClientDbPaths {
  ClientDbPaths._();

  /// Root node for user profiles.  Deliberately **without** the
  /// `delicia/` prefix — the Leader's auth service uses the bare
  /// `users` node, and both sides must agree on it or the profile screen
  /// would never find the record that registration just created.
  static const String usersRoot = 'users';

  /// Child node holding the delivery addresses of a user.
  static const String addressesRoot = 'addresses';

  /// Node holding a user's avatar upload in Firebase Storage.
  static const String avatarsRoot = 'avatars';
}
