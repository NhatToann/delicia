import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// The destinations of the app-wide bottom navigation bar.
///
/// [AppBottomNav] renders them; this class owns what *tapping* one does,
/// so every screen navigates to the same place for the same icon.
///
/// The bar is the app's spine: the customer must never wonder whether the
/// "Orders" tab means something different on the home screen and on the
/// product-detail screen. So the routing lives here, once.
class AppNavDestination {
  const AppNavDestination._();

  /// Home — the catalogue. Always the root of the client flow.
  static const int home = 0;

  /// Discover — the search / browse screen.
  static const int discover = 1;

  /// Orders — the customer's order history.
  static const int orders = 2;

  /// Live delivery tracking.
  static const int tracking = 3;

  /// The number of destinations in the bar.
  static const int count = 4;

  /// Navigates to the screen a destination represents.
  ///
  /// [root] is the context of the screen that owns the bar. Tapping a
  /// destination replaces the whole stack rather than pushing onto it, so
  /// the customer can never end up with ten screens of the same tab
  /// stacked up.
  static void go(BuildContext context, int index) {
    switch (index) {
      case discover:
        context.go('/client/search-category');
      case orders:
        context.go('/client/orders');
      case tracking:
        context.go('/client/map');
      case home:
      default:
        context.go('/client/home');
    }
  }
}
