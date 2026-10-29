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

  /// Root of the Firebase-hosted catalogue imagery.
  ///
  /// Every dish photo is served from Firebase and its **absolute URL** is
  /// stored in the Realtime Database (`products/{id}/picture`). Nothing in
  /// the app hardcodes an image path — the database row is the only source
  /// of truth, so re-hosting an image is a data change, not a release.
  ///
  /// The images live on **Firebase Hosting** (the project's Storage bucket
  /// cannot be created while the project's billing account is disabled, and
  /// `storage.buckets.create` is refused by Cloud Storage with
  /// `accountDisabled`). Hosting is part of the same Firebase project, so
  /// the URLs are still Firebase URLs and are served over HTTPS with a
  /// long-lived cache header.
  ///
  /// The trailing slash is part of the URL — [CatalogueImages] builds the
  /// full URL from it.
  static const String catalogueImageBaseUrl =
      'https://delicia-60e0a.web.app/products';

  // Map provider (UC-03). OSM's public tile endpoint resets connections on
  // some mobile networks; use CARTO's CDN when a key is supplied. The key is
  // a public client tile key and should be restricted to the Android app ID.
  static const String cartoBasemapApiKey = String.fromEnvironment(
    'CARTO_BASEMAP_API_KEY',
  );
  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  static String get tileServerUrl => cartoBasemapApiKey.isEmpty
      ? _osmTileUrl
      : 'https://basemaps.cartocdn.com/rastertiles/voyager/'
            '{z}/{x}/{y}.png?key=$cartoBasemapApiKey';

  /// OSMF blocks generic HTTP client identities. Keep this stable and clearly
  /// identify the app so tile traffic can be distinguished from library
  /// defaults. The source repo is the project's public contact point.
  static const String tileUserAgent =
      'DeliciaFoodDelivery/1.0.0 (+https://github.com/NhatToann/delicia)';

  /// Required visible attribution for the selected OSM-derived tile source.
  static String get tileAttribution => cartoBasemapApiKey.isEmpty
      ? '© OpenStreetMap contributors'
      : 'Map tiles by CARTO (CC BY 3.0) · OpenStreetMap (ODbL)';

  /// Default delivery fee in VND/USD — used by CheckoutScreen as the
  /// "Delivery fee" line item until the backend returns it dynamically.
  static const double defaultDeliveryFee = 2.5;

  // ---- Delivery estimate --------------------------------------------------
  /// Minutes shown as "Estimated Delivery" on the Payment screen
  /// (Figma 4.3 - D draws "25 mins"). The courier's real ETA is only
  /// known once an order is dispatched, so this is the restaurant's
  /// advertised lead time until then.
  static const int estimatedDeliveryMinutes = 25;

  // ---- payOS (optional online gateway) ------------------------------------
  //
  // payOS needs a client id, an api key and a checksum key, and every
  // request has to be signed with HMAC-SHA256. The checksum key must
  // never ship inside a client app, so the credentials are empty by
  // default and the PayOS method stays hidden until they are filled in.
  //
  // For production, point [payosApiBase] at a small backend that holds
  // the checksum key and forwards the request.
  static const String payosClientId = '';
  static const String payosApiKey = '';
  static const String payosChecksumKey = '';

  /// Merchant API host. Swappable so a self-hosted proxy can be used.
  static const String payosApiBase = 'https://api-merchant.payos.vn';

  /// Conversion rate used to turn the app's currency into VND, which is
  /// the only currency payOS accepts.
  static const int payosVndRate = 25000;

  /// Whether enough credentials are present to talk to payOS.
  static bool get payosConfigured =>
      payosClientId.isNotEmpty &&
      payosApiKey.isNotEmpty &&
      payosChecksumKey.isNotEmpty;
}

/// Single source of truth for every money figure the Cart and Checkout
/// screens display.
///
/// The Figma mockups (nodes `202:1358` / `199:1715`) show illustrative
/// amounts — `$20.00`, `$5.00`, `$3.00`, `$40.00` — for a two-item cart.
/// Those are *samples of a layout*, not values to copy into the UI. Every
/// amount rendered by the app is derived from the real [ProductCart.price]
/// values plus the constants declared here, so nothing is hardcoded.
///
/// Both the cart panel and the checkout page read from this class, which
/// keeps the two screens consistent even if the fee or the tax changes.
class CartPricing {
  const CartPricing._();

  /// Flat delivery fee added to every order.
  ///
  /// Kept equal to [Environment.defaultDeliveryFee] so the legacy callers
  /// that still read that constant stay in sync with the new source.
  static const double deliveryFee = Environment.defaultDeliveryFee;

  /// Tax rate applied to the subtotal (5 %).
  static const double taxRate = 0.05;

  /// Tax charged on [subtotal].
  static double taxOf(double subtotal) => subtotal * taxRate;

  /// Grand total = subtotal + tax + delivery.
  static double totalOf(double subtotal) =>
      subtotal + taxOf(subtotal) + deliveryFee;
}
