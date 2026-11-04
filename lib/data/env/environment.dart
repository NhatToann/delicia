/// App-wide configuration constants.
class Environment {
  Environment._();

  /// The Realtime Database instance lives in `asia-southeast1` for this
  /// project — pointing `FirebaseDatabase.instance` at the wrong region makes
  /// the SDK get killed by the server with the error
  /// "Database lives in a different region".
  static const String firebaseDatabaseUrl =
      'https://delicia-60e0a-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// The Web API key of the Firebase project.
  ///
  /// A *client* API key is not a secret — it ships inside every build of
  /// the app anyway (`google-services.json` → `google_api_key`) and only
  /// identifies the project. It is needed here because the admin console
  /// creates the delivery drivers through a **secondary Firebase app**,
  /// which cannot read the API key from the default app on every
  /// platform.
  static const String firebaseApiKey = 'AIzaSyAQZB-sHa8T9QANnusCPrgmRxMSSGEsvk8';

  /// The Firebase project id (used to build the options of the secondary
  /// app that owns the driver accounts).
  static const String firebaseProjectId = 'delicia-60e0a';

  /// The messaging sender id of the Android app (also part of the
  /// secondary app options).
  static const String firebaseSenderId = '204797923977';

  /// The Android app id of the default Firebase app.
  static const String firebaseAppId = '1:204797923977:android:c0abbb80396d9fd3b76c58';

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

  /// Fallback delivery fee in VND — used by the cart summary as the
  /// "Delivery fee" line item before the real distance-based fee is
  /// known.
  ///
  /// The app's currency is VND, so this is a number of dong, not a
  /// number of dollars. The checkout screen replaces it with
  /// [CartPricing.deliveryFeeVnd] once the road distance is known.
  static const double defaultDeliveryFee = 25000;

  /// The restaurant / store location coordinates (Bếp Delicia, Quận 1, TP. Hồ Chí Minh).
  static const double restaurantLatitude = 10.7769;
  static const double restaurantLongitude = 106.7009;

  // ---- Delivery estimate --------------------------------------------------
  /// Minutes shown as "Estimated Delivery" on the Payment screen
  /// (Figma 4.3 - D draws "25 mins"). The courier's real ETA is only
  /// known once an order is dispatched, so this is the restaurant's
  /// advertised lead time until then.
  static const int estimatedDeliveryMinutes = 25;
}

/// Single source of truth for every money figure the Cart and Checkout
/// screens display.
///
/// **Every amount in this class is in VND.** The app's currency is the
/// Vietnamese dong and the Realtime Database stores dong, so nothing in
/// the pricing pipeline converts between currencies.
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

  /// Flat delivery fee added to every order, in VND.
  ///
  /// Kept equal to [Environment.defaultDeliveryFee] so the legacy callers
  /// that still read that constant stay in sync with the new source.
  static const double deliveryFee = Environment.defaultDeliveryFee;

  /// Tax rate applied to the subtotal (5 %).
  static const double taxRate = 0.05;

  /// Tax charged on [subtotal].
  static double taxOf(double subtotal) => subtotal * taxRate;

  /// Grand total = subtotal + tax + delivery.
  static double totalOf(double subtotal, {double? delivery}) =>
      subtotal + taxOf(subtotal) + (delivery ?? deliveryFee);

  /// Computes the shipping fee for a road distance, in VND.
  ///
  /// The app's currency is VND and so is the database, so the fee is
  /// returned in the same unit it is stored in — no conversion.
  ///
  /// - Under 1km (< 1.0 km): 0 VND (free)
  /// - From 1-3km (1.0 <= km <= 3.0): 5,000 VND / km
  /// - From 3-8km (3.0 < km <= 8.0): 8,000 VND / km
  /// - Above 8km (> 8.0 km): 10,000 VND / km
  static double deliveryFeeVnd(double distanceKm) {
    if (distanceKm < 1.0) {
      return 0.0;
    } else if (distanceKm <= 3.0) {
      return distanceKm * 5000.0;
    } else if (distanceKm <= 8.0) {
      return distanceKm * 8000.0;
    } else {
      return distanceKm * 10000.0;
    }
  }

  /// Computes driver earnings in VND:
  /// - Under 1km: 5,000 VND (minimum base pay so driver doesn't deliver for free).
  /// - Above 1km: 90% of distance-based delivery fee.
  static double driverEarningsVnd(double distanceKm) {
    if (distanceKm < 1.0) {
      return 5000.0;
    }
    return deliveryFeeVnd(distanceKm) * 0.90;
  }
}
