/// App-wide configuration constants.
///
/// Replace [firebaseDatabaseUrl] with the real Firebase Realtime Database URL
/// from the Firebase console for project `delicia-60e0a`.
class Environment {
  Environment._();

  /// The Realtime Database instance lives in `asia-southeast1` for this
  /// project — pointing `FirebaseDatabase.instance` at the wrong region makes
  /// the SDK get killed by the server with the error
  /// "Database lives in a different region".
  static const String firebaseDatabaseUrl =
      'https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app';
}
