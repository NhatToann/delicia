import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/bloc/cart/cart_bloc.dart';
import '../../l10n/generated/app_localizations.dart';
import '../helpers/l10n_extension.dart';
import '../themes/colors_frave.dart';
import '../themes/type_frave.dart';

/// The one bottom navigation bar for the whole app.
///
/// Every client screen that has a bottom bar uses **this** widget, so the
/// navigation never changes shape from one screen to the next: the same
/// four evenly spaced destinations (Home / Discover / Orders / Tracking),
/// the same 64 px bar and the same yellow selection pill.
///
/// The bar was originally defined inline in `home_screen.dart`. It was
/// moved here so the product-detail and payment screens — which used to
/// draw a *different*, Figma-illustrative orange bar with baked-in icons —
/// could reuse the real one. A screen that wants a bar puts this widget in
/// its `Scaffold.bottomNavigationBar` and wires the two callbacks.
class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.cartCount,
    this.onTapCart,
    this.showCart = false,
  });

  /// Which destination is currently selected.
  final int currentIndex;

  /// Fired with the index of the destination that was tapped.
  final ValueChanged<int> onTap;

  /// Number of items in the cart — shown on the floating cart pill.
  ///
  /// When null the badge is read from the [CartBloc] instead, which is
  /// the normal case: every screen shows the same live count without
  /// having to wire it up by hand.
  final int? cartCount;

  /// Fired when the floating cart pill is tapped.
  ///
  /// When null the pill is hidden, which is what the payment screen wants:
  /// the customer is already checking out, so a cart button there would be
  /// a dead end.
  final VoidCallback? onTapCart;

  /// Whether to render the optional floating cart pill. Kept opt-in so the
  /// navigation destinations remain evenly spaced by default.
  final bool showCart;

  /// Height of the bar itself, excluding the system gesture inset.
  static const double barHeight = 64;

  /// Horizontal inset of the floating cart pill from the right edge.
  static const double cartInset = 16;

  /// Height of the floating cart pill.
  static const double cartPillHeight = 44;

  /// Space reserved on the right so the floating cart button never covers
  /// the final navigation destination (currently live tracking).
  static const double cartReservedWidth = 88;

  static List<_NavItem> _items(AppLocalizations l10n) => <_NavItem>[
    _NavItem(icon: Icons.home_rounded, label: l10n.navHome),
    _NavItem(icon: Icons.explore_outlined, label: l10n.navDiscover),
    _NavItem(icon: Icons.receipt_long_outlined, label: l10n.navOrders),
    _NavItem(icon: Icons.location_on_outlined, label: l10n.navTracking),
  ];

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final items = _items(context.l10n);
    final reserveCart = showCart && onTapCart != null;
    return Container(
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        border: Border(
          top: BorderSide(color: ColorsFrave.outlineVariant, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: SizedBox(
          height: barHeight + safeBottom,
          child: Stack(
            children: <Widget>[
              Padding(
                // The cart pill is an independent floating action on the
                // right. Reserve its hit area inside the nav layout instead
                // of stacking it over the last tab.
                padding: EdgeInsets.only(
                  right: reserveCart ? cartReservedWidth : 0,
                ),
                child: NavigationBar(
                  elevation: 0,
                  backgroundColor: ColorsFrave.surfaceColor,
                  indicatorColor: ColorsFrave.pillYellow,
                  surfaceTintColor: Colors.transparent,
                  height: barHeight,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  selectedIndex: currentIndex,
                  onDestinationSelected: onTap,
                  destinations: <NavigationDestination>[
                    for (var i = 0; i < items.length; i++)
                      NavigationDestination(
                        icon: Icon(
                          items[i].icon,
                          size: 24,
                          color: ColorsFrave.lightGrey,
                        ),
                        selectedIcon: Icon(
                          items[i].icon,
                          size: 24,
                          color: ColorsFrave.navOrange,
                        ),
                        label: items[i].label,
                      ),
                  ],
                ),
              ),
              if (showCart && onTapCart != null)
                // The [BlocBuilder] wraps the [Positioned] rather than the
                // other way round: a [Positioned] hands its child a loose
                // constraint, and the builder's listener subtree would
                // then size itself to nothing.
                _CartBadge(
                  bloc: _cartBloc(context),
                  count: cartCount,
                  onTap: onTapCart!,
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// The cart badge.
  ///
  /// When the count is not given it is read from the [CartBloc] and the
  /// bar **rebuilds** whenever the cart changes — a badge that only shows
  /// the count from the moment the screen opened would be wrong the
  /// moment the customer adds a dish.
  ///
  /// The bloc is read defensively: a screen that is rendered in isolation
  /// (a widget test, a preview) may not have the cart bloc above it, and
  /// a missing provider must not take the whole bottom bar down.
  /// The cart bloc, or null when the screen has none above it.
  ///
  /// The provider is looked up with `context.read`, which throws the
  /// original `ProviderNotFoundException` — `BlocProvider.of` would wrap it
  /// in a `FlutterError` that cannot be caught.
  ///
  /// A screen rendered in isolation (a widget test, a preview) has no cart
  /// bloc above it. That must not take the whole bar down, so the badge
  /// simply shows zero.
  CartBloc? _cartBloc(BuildContext context) {
    try {
      return context.read<CartBloc>();
    } on ProviderNotFoundException {
      return null;
    }
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// The floating cart pill, with its live badge.
///
/// The count comes from the [CartBloc] so it updates the moment the
/// customer adds a dish — a badge that only showed the count from the
/// moment the screen opened would be wrong straight away.
class _CartBadge extends StatelessWidget {
  const _CartBadge({
    required this.bloc,
    required this.count,
    required this.onTap,
  });

  /// The cart bloc, or null when the screen has none above it.
  final CartBloc? bloc;

  /// An explicit count, which wins over the bloc's.
  final int? count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final explicit = count;
    if (explicit != null) {
      return Positioned(
        right: AppBottomNav.cartInset,
        top: (AppBottomNav.barHeight - AppBottomNav.cartPillHeight) / 2,
        child: _CartPill(count: explicit, onTap: onTap),
      );
    }
    final cartBloc = bloc;
    if (cartBloc == null) {
      return Positioned(
        right: AppBottomNav.cartInset,
        top: (AppBottomNav.barHeight - AppBottomNav.cartPillHeight) / 2,
        child: _CartPill(count: 0, onTap: onTap),
      );
    }
    return BlocBuilder<CartBloc, CartState>(
      bloc: cartBloc,
      buildWhen: (a, b) => a.quantityCart != b.quantityCart,
      builder: (context, state) => Positioned(
        right: AppBottomNav.cartInset,
        top: (AppBottomNav.barHeight - AppBottomNav.cartPillHeight) / 2,
        child: _CartPill(count: state.quantityCart, onTap: onTap),
      ),
    );
  }
}

/// Floating cart button. Tapping opens the cart route; when the cart has
/// items, the badge updates from the [CartBloc].
class _CartPill extends StatelessWidget {
  const _CartPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0
          ? context.l10n.cartBadgeLabel(count)
          : context.l10n.navCart,
      child: Material(
        color: ColorsFrave.navOrange,
        shape: const StadiumBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.shopping_bag_rounded,
                  size: 18,
                  color: ColorsFrave.onOrange,
                ),
                if (count > 0) ...<Widget>[
                  const SizedBox(width: 6),
                  Text(
                    '$count',
                    style: FraveText.bold(
                      13,
                      color: ColorsFrave.onOrange,
                      height: 1,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
