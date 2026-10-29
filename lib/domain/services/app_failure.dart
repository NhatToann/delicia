/// Stable, localisable identifiers for the failures the domain layer raises.
///
/// The UI never renders the raw message carried by an exception. Instead it
/// looks the [AppFailure.code] up in `lib/presentation/helpers/
/// error_localizer.dart` and shows the translated sentence. Keeping the
/// codes in one file means a service can be reworded without touching the
/// translation table, and the table can be translated without touching a
/// single service.
class AppFailureCodes {
  AppFailureCodes._();

  // ---- Auth ----------------------------------------------------------------
  static const String authInvalidCredentials = 'auth.invalidCredentials';
  static const String authEmailInUse = 'auth.emailInUse';
  static const String authWeakPassword = 'auth.weakPassword';
  static const String authProviderDisabled = 'auth.providerDisabled';
  static const String authAccountDisabled = 'auth.accountDisabled';
  static const String authTooManyRequests = 'auth.tooManyRequests';
  static const String authInvalidEmail = 'auth.invalidEmail';
  static const String authNetwork = 'auth.network';
  static const String authUnknown = 'auth.unknown';
  static const String authLoginNoUser = 'auth.loginNoUser';
  static const String authRegisterNoUser = 'auth.registerNoUser';
  static const String authProfileCreate = 'auth.profileCreate';
  static const String authProfileUpdate = 'auth.profileUpdate';
  static const String authUnexpectedLogin = 'auth.unexpectedLogin';
  static const String authUnexpectedRegister = 'auth.unexpectedRegister';
  static const String authUnexpectedForgot = 'auth.unexpectedForgot';

  // ---- Firebase bootstrap --------------------------------------------------
  static const String firebaseNotInitialised = 'firebase.notInitialised';
  static const String firebaseNotInitialisedHint =
      'firebase.notInitialisedHint';

  // ---- Catalogue -----------------------------------------------------------
  static const String productsLoad = 'products.load';
  static const String productsLoadByCategory = 'products.loadByCategory';
  static const String productsLoadOne = 'products.loadOne';
  static const String productsSearch = 'products.search';
  static const String productsTopLoad = 'products.topLoad';
  static const String productsImagesLoad = 'products.imagesLoad';
  static const String categoriesLoad = 'categories.load';
  static const String categoryAdd = 'category.add';
  static const String categoryDelete = 'category.delete';
  static const String productAdd = 'product.add';
  static const String productDelete = 'product.delete';
  static const String productStatusUpdate = 'product.statusUpdate';

  // ---- Orders --------------------------------------------------------------
  static const String ordersLoad = 'orders.load';
  static const String ordersLoadOne = 'orders.loadOne';
  static const String ordersCreate = 'orders.create';
  static const String ordersEmpty = 'orders.empty';
  static const String ordersIdGenerate = 'orders.idGenerate';
  static const String ordersCancel = 'orders.cancel';
  static const String ordersWatch = 'orders.watch';

  // ---- Payment -------------------------------------------------------------
  static const String paymentStart = 'payment.start';
  static const String paymentComplete = 'payment.complete';
  static const String paymentVerify = 'payment.verify';
  static const String paymentCancelled = 'payment.cancelled';
  static const String paymentVerifyDetail = 'payment.verifyDetail';
  static const String paymentStartDetail = 'payment.startDetail';
  static const String paymentGatewayNotConfigured =
      'payment.gatewayNotConfigured';
  static const String paymentGatewayNoLink = 'payment.gatewayNoLink';
  static const String paymentGatewayRejected = 'payment.gatewayRejected';
  static const String paymentGatewayFailed = 'payment.gatewayFailed';
  static const String paymentGatewayUnreadable = 'payment.gatewayUnreadable';

  // ---- Routing -------------------------------------------------------------
  static const String routeMalformed = 'route.malformed';
  static const String routeMalformedDetail = 'route.malformedDetail';
  static const String routeNoGeometry = 'route.noGeometry';
  static const String routeNoRoutes = 'route.noRoutes';
  static const String routeHttp = 'route.http';
  static const String routeRefused = 'route.refused';
  static const String routeFailed = 'route.failed';
  static const String routeTimeout = 'route.timeout';

  // ---- Realtime ------------------------------------------------------------
  static const String realtimeSubscribe = 'realtime.subscribe';
  static const String realtimeListener = 'realtime.listener';
  static const String realtimePublish = 'realtime.publish';

  // ---- Tracking ------------------------------------------------------------
  static const String trackingStart = 'tracking.start';

  // ---- Generic -------------------------------------------------------------
  static const String generic = 'generic';
}

/// Converts anything thrown by the domain layer into an [AppFailure].
///
/// Domain exceptions already carry a code; anything else (a raw
/// [Exception], a `TypeError`, a Firebase error, ...) is wrapped so the
/// presentation layer always has a code to translate.
AppFailure asFailure(Object error) {
  if (error is AppFailure) return error;
  return AppFailure(AppFailureCodes.generic, error.toString());
}

/// An exception that identifies *what* went wrong rather than *how it reads*.
///
/// [code] is one of the constants on [AppFailureCodes]. [detail] carries the
/// underlying error for logs and for the messages that embed it.
class AppFailure implements Exception {
  final String code;
  final String? detail;

  const AppFailure(this.code, [this.detail]);

  @override
  String toString() => detail == null ? code : '$code: $detail';
}
