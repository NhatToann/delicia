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

  // NOTE: The original Frave backend exposed a `http://…/uploads/` URL and
  // a separate socket.io endpoint. We have migrated to local assets for
  // images and Firebase Realtime Database for data, so those constants have
  // been removed. The Google Maps API key + socket server URL will be
  // re-introduced in UC-03 (realtime map) and UC-12 (deploy polish).
  static const String googleMapsApiKey = 'YOUR_GOOGLE_MAPS_API_KEY';

  /// Default delivery fee in VND/USD — used by CheckoutScreen as the
  /// "Delivery fee" line item until the backend returns it dynamically.
  static const double defaultDeliveryFee = 2.5;
}