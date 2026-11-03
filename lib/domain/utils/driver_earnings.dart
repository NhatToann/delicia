import '../../data/env/environment.dart';
import '../../data/services/route_service.dart';
import '../models/lat_lng_point.dart';
import '../models/order_record.dart';

/// Single source of truth for computing driver earnings per order.
///
/// Policy:
/// - Road distance is measured from the restaurant (Bếp Delicia, Quận 1: 10.7769, 106.7009)
///   to the order delivery address.
/// - Shipping fee is computed by [CartPricing.deliveryFeeVnd]:
///   * < 1km: 0 VND (free)
///   * 1 - 3km: 5,000 VND / km
///   * 3 - 8km: 8,000 VND / km
///   * > 8km: 10,000 VND / km
/// - Driver earnings: 90% of the delivery fee for that order.
class DriverEarnings {
  const DriverEarnings._();

  /// Estimates the road distance in kilometres from the restaurant to the order dropoff.
  static double calculateDistanceKm(OrderRecord order) {
    if (order.latitude == 0 || order.longitude == 0) {
      return 1.0;
    }
    const origin = LatLngPoint(
      latitude: Environment.restaurantLatitude,
      longitude: Environment.restaurantLongitude,
    );
    final dest = LatLngPoint(
      latitude: order.latitude,
      longitude: order.longitude,
    );
    final directMeters = RouteService.distanceMeters(origin, dest);
    return (directMeters * 1.2) / 1000.0;
  }

  /// Returns driver earnings in USD (for internal usage / [Money.format]).
  static double earningsUsdForOrder(OrderRecord order) {
    final distKm = calculateDistanceKm(order);
    return CartPricing.driverEarningsUsd(distKm);
  }

  /// Returns driver earnings in VND.
  static double earningsVndForOrder(OrderRecord order) {
    final distKm = calculateDistanceKm(order);
    return CartPricing.driverEarningsVnd(distKm);
  }
}

