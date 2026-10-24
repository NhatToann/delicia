/// App-wide configuration constants.
class Environment {
  Environment._();

  /// The Realtime Database instance lives in `asia-southeast1` for this
  /// project — pointing `FirebaseDatabase.instance` at the wrong region makes
  /// the SDK get killed by the server with the error
  /// "Database lives in a different region".
  static const String firebaseDatabaseUrl =
      'https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Convenience: products, categories and orders are all stored under
  /// `delicia/...` to keep the Realtime DB tidy. Override if your team has a
  /// different naming convention.
  static const String dbRoot = 'delicia';

  // Map provider (UC-03).
  //
  // We use OpenStreetMap via the community `flutter_map` package
  // (https://pub.dev/packages/flutter_map) — no API key, no billing, no
  // Google Cloud project required. Override the URL if you want to
  // self-host tiles or use a different provider (e.g. Stamen, MapTiler).
  //
  // Production note: the public OSM tile server
  // (https://tile.openstreetmap.org) is for hobby/demo use; if you expect
  // heavy traffic, switch to a CDN or your own tile server.
  static const String tileServerUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  /// Attribution string required by the OSM tile usage policy.
  /// https://operations.osmfoundation.org/policies/tiles/
  static const String tileAttribution =
      '© OpenStreetMap contributors';

  /// Default delivery fee in VND/USD — used by CheckoutScreen as the
  /// "Delivery fee" line item until the backend returns it dynamically.
  static const double defaultDeliveryFee = 2.5;
}