import '../../domain/services/app_failure.dart';
import '../../l10n/generated/app_localizations.dart';

/// Turns a domain-layer failure into a sentence the customer can read.
///
/// The domain layer never writes user-facing copy: it raises an
/// [AppFailure] carrying a stable [AppFailureCodes] identifier. This
/// helper is the single place where those identifiers are turned into
/// Vietnamese text, which keeps the translation table in one file and
/// means a service can be reworded without touching its callers.
String localizeFailure(AppLocalizations l10n, AppFailure failure) {
  final detail = failure.detail;
  switch (failure.code) {
    // ---- Auth --------------------------------------------------------------
    case AppFailureCodes.authInvalidCredentials:
      return l10n.errorAuthInvalidCredentials;
    case AppFailureCodes.authEmailInUse:
      return l10n.errorAuthEmailInUse;
    case AppFailureCodes.authWeakPassword:
      return l10n.errorAuthWeakPassword;
    case AppFailureCodes.authProviderDisabled:
      return l10n.errorAuthProviderDisabled;
    case AppFailureCodes.authAccountDisabled:
      return l10n.errorAuthAccountDisabled;
    case AppFailureCodes.authTooManyRequests:
      return l10n.errorAuthTooManyRequests;
    case AppFailureCodes.authInvalidEmail:
      return l10n.errorAuthInvalidEmail;
    case AppFailureCodes.authNetwork:
      return l10n.errorAuthNetwork;
    case AppFailureCodes.authLoginNoUser:
      return l10n.errorAuthLoginNoUser;
    case AppFailureCodes.authRegisterNoUser:
      return l10n.errorAuthRegisterNoUser;
    case AppFailureCodes.authProfileCreate:
      return l10n.errorAuthProfileCreate(detail ?? '');
    case AppFailureCodes.authProfileUpdate:
      return l10n.errorAuthProfileUpdate(detail ?? '');
    case AppFailureCodes.authUnexpectedLogin:
      return l10n.errorAuthUnexpectedLogin(detail ?? '');
    case AppFailureCodes.authUnexpectedRegister:
      return l10n.errorAuthUnexpectedRegister(detail ?? '');
    case AppFailureCodes.authUnexpectedForgot:
      return l10n.errorAuthUnexpectedForgot(detail ?? '');
    case AppFailureCodes.authUnknown:
      return l10n.errorAuthUnknown(detail ?? '');

    // ---- Firebase bootstrap ------------------------------------------------
    case AppFailureCodes.firebaseNotInitialised:
      return l10n.errorFirebaseNotInitialised;

    // ---- Catalogue ---------------------------------------------------------
    case AppFailureCodes.productsLoad:
      return l10n.errorProductsLoad(detail ?? '');
    case AppFailureCodes.productsLoadByCategory:
      return l10n.errorProductsLoadByCategory(detail ?? '');
    case AppFailureCodes.productsLoadOne:
      return l10n.errorProductLoad(detail ?? '');
    case AppFailureCodes.productsSearch:
      return l10n.errorProductsSearch(detail ?? '');
    case AppFailureCodes.productsTopLoad:
      return l10n.errorProductsTopLoad(detail ?? '');
    case AppFailureCodes.productsImagesLoad:
      return l10n.errorProductsImagesLoad(detail ?? '');
    case AppFailureCodes.categoriesLoad:
      return l10n.errorCategoriesLoad(detail ?? '');
    case AppFailureCodes.categoryAdd:
      return l10n.errorCategoryAdd(detail ?? '');
    case AppFailureCodes.categoryDelete:
      return l10n.errorCategoryDelete(detail ?? '');
    case AppFailureCodes.productAdd:
      return l10n.errorProductAdd(detail ?? '');
    case AppFailureCodes.productDelete:
      return l10n.errorProductDelete(detail ?? '');
    case AppFailureCodes.productStatusUpdate:
      return l10n.errorProductStatusUpdate(detail ?? '');

    // ---- Orders ------------------------------------------------------------
    case AppFailureCodes.ordersLoad:
      return l10n.errorOrdersLoad(detail ?? '');
    case AppFailureCodes.ordersLoadOne:
      return l10n.errorOrderLoad(detail ?? '');
    case AppFailureCodes.ordersCreate:
      return l10n.errorOrderCreate(detail ?? '');
    case AppFailureCodes.ordersEmpty:
      return l10n.errorOrderEmpty;
    case AppFailureCodes.ordersIdGenerate:
      return l10n.errorOrderIdGenerate;
    case AppFailureCodes.ordersCancel:
      return l10n.errorOrderCancel(detail ?? '');
    case AppFailureCodes.ordersWatch:
      return l10n.errorOrderWatch(detail ?? '');

    // ---- Payment -----------------------------------------------------------
    case AppFailureCodes.paymentStart:
      return l10n.errorPaymentStart;
    case AppFailureCodes.paymentComplete:
      return l10n.errorPaymentComplete;
    case AppFailureCodes.paymentVerify:
      return l10n.errorPaymentVerify;
    case AppFailureCodes.paymentCancelled:
      return l10n.errorPaymentCancelled;
    case AppFailureCodes.paymentVerifyDetail:
      return l10n.errorPaymentVerifyDetail(detail ?? '');
    case AppFailureCodes.paymentStartDetail:
      return l10n.errorPaymentStartDetail(detail ?? '');
    case AppFailureCodes.paymentGatewayNotConfigured:
      return l10n.errorPaymentGatewayNotConfigured;
    case AppFailureCodes.paymentGatewayNoLink:
      return l10n.errorPaymentGatewayNoLink;
    case AppFailureCodes.paymentGatewayRejected:
      return l10n.errorPaymentGatewayRejected;
    case AppFailureCodes.paymentGatewayFailed:
      return l10n.errorPaymentGatewayFailed(int.tryParse(detail ?? '') ?? 0);
    case AppFailureCodes.paymentGatewayUnreadable:
      return l10n.errorPaymentGatewayUnreadable(int.tryParse(detail ?? '') ?? 0);

    // ---- Routing -----------------------------------------------------------
    case AppFailureCodes.routeMalformed:
      return l10n.errorRouteMalformed;
    case AppFailureCodes.routeMalformedDetail:
      return l10n.errorRouteMalformedDetail(detail ?? '');
    case AppFailureCodes.routeNoGeometry:
      return l10n.errorRouteNoGeometry;
    case AppFailureCodes.routeNoRoutes:
      return l10n.errorRouteNoRoutes;
    case AppFailureCodes.routeHttp:
      return l10n.errorRouteHttp(int.tryParse(detail ?? '') ?? 0);
    case AppFailureCodes.routeRefused:
      return l10n.errorRouteRefused(detail ?? '');
    case AppFailureCodes.routeFailed:
      return l10n.errorRouteFailed(detail ?? '');
    case AppFailureCodes.routeTimeout:
      return l10n.errorRouteTimeout(detail ?? '');

    // ---- Realtime ----------------------------------------------------------
    case AppFailureCodes.realtimeSubscribe:
      return l10n.errorRealtimeSubscribe(detail ?? '');
    case AppFailureCodes.realtimeListener:
      return l10n.errorRealtimeListener(detail ?? '');
    case AppFailureCodes.realtimePublish:
      return l10n.errorRealtimePublish(detail ?? '');

    // ---- Tracking ----------------------------------------------------------
    case AppFailureCodes.trackingStart:
      return l10n.errorTrackingStart(detail ?? '');

    default:
      return detail == null
          ? l10n.errorGeneric
          : l10n.errorWithDetail(detail);
  }
}
