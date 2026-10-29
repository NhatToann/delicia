import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../cart/cart_screen.dart';
import 'widgets/order_filter_chips.dart';
import 'widgets/order_row.dart';
import 'widgets/orders_empty_state.dart';

/// ClientOrdersScreen — the client's order history.
///
/// Figma nodes:
///   147:2153 — "4.1.1 - B - My Orders"      (empty state)
///   147:2106 — "4.1.1 - C - My Orders - Active" (one order)
///
/// Layout on a 393 x 852 frame:
///
///   status bar      h32, fill #F5CB58
///   back arrow      x35  y81   8 x 13
///   title           "My Orders" centred, League Spartan Bold 28 #F8F8F8
///   filter chips    y164  h28  (Active / Completed / Cancelled)
///   content         y211+ (dividers at y211 and y345, 323 px wide)
///
/// The header band is yellow (#F5CB58) — same as the home screen — and
/// the content area below the chips is the light kit background.
///
/// ## Why the class is named `ClientOrdersView`
///
/// The screen used to be a `StatelessWidget` called `ClientOrdersScreen`,
/// and the name is kept in the comments on purpose — but the *class name*
/// had to change. The screen now needs a `State` (it subscribes to the
/// auth stream), so it became a `StatefulWidget`.
///
/// Flutter's hot reload reuses the existing [Element] when the widget's
/// runtime type is unchanged, and an element created for a
/// `StatelessWidget` cannot be reused for a `StatefulWidget`: the
/// framework casts the old element to `StatefulElement` and the cast
/// fails, which paints the whole screen red with an `ErrorWidget`.
///
/// Renaming the class changes its runtime type, so the framework builds a
/// fresh element instead of trying to recycle the old one — the hot
/// reload lands cleanly without a restart.
class ClientOrdersView extends StatefulWidget {
  const ClientOrdersView({super.key});

  @override
  State<ClientOrdersView> createState() => _ClientOrdersViewState();
}

class _ClientOrdersViewState extends State<ClientOrdersView> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Bind the My Orders stream to the signed-in client. The user may
    // already be signed in when this screen mounts (e.g. deep link), so
    // we read the current state *and* listen for changes.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindToClient());
  }

  void _bindToClient() {
    if (!mounted) return;
    final authBloc = context.read<AuthBloc>();
    final ordersBloc = context.read<OrdersBloc>();

    void apply(AuthState state) {
      if (!mounted) return;
      final clientId = state.user?.uid ?? '';
      if (clientId.isEmpty) {
        ordersBloc.add(const OnClearMyOrdersEvent());
      } else {
        ordersBloc.add(OnLoadMyOrdersEvent(clientId));
      }
    }

    // 1) Immediate: the user may already be signed in.
    apply(authBloc.state);

    // 2) Ongoing: sign-in / sign-out / profile refresh.
    _authSub = authBloc.stream.listen(apply, onError: (_) {});
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: Column(
        children: <Widget>[
          const _OrdersHeader(),
          // Filter chips + content share the remaining space.
          Expanded(
            child: BlocBuilder<OrdersBloc, OrdersState>(
              builder: (context, state) {
                return Column(
                  children: <Widget>[
                    // Figma: the chip row starts at y164, the header
                    // band ends at y129 → 35 px of gap.
                    Padding(
                      padding: const EdgeInsets.only(top: 35, bottom: 20),
                      child: OrderFilterChips(
                        selected: state.filter,
                        onSelected: (filter) => context.read<OrdersBloc>().add(
                          OnChangeOrderFilterEvent(filter),
                        ),
                      ),
                    ),
                    Expanded(child: _OrdersContent(state: state)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // The app-wide bottom bar — the same one every screen uses.
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppNavDestination.orders,
        onTap: (index) => AppNavDestination.go(context, index),
        onTapCart: _openCart,
      ),
    );
  }

  /// Opens the cart drawer — the same overlay the home screen uses.
  void _openCart() {
    CartOverlay.show(
      context,
      onCheckout: () => context.push('/client/payment'),
    );
  }
}

/// Yellow header band with the back arrow and the "My Orders" title.
///
/// Figma node 147:2106: the band covers y0 → y129 (the top 32 px is
/// the system status bar), the title sits at y73 with the back arrow at
/// x35 / y81.
///
/// The band is a fixed 129 px so the chip row below always lands on
/// the Figma y164 baseline, whatever the device's status bar height.
class _OrdersHeader extends StatelessWidget {
  const _OrdersHeader();

  /// Figma: the yellow band ends at y129 and the system status bar is
  /// 32 px tall, so the band is [statusBarHeight] + 97 px.
  static const double figmaStatusBarHeight = 32;
  static const double bandContentHeight = 97;

  @override
  Widget build(BuildContext context) {
    final gutter = MediaQuery.sizeOf(context).width < 380 ? 20.0 : 35.0;
    // The status bar is drawn by the OS on top of the band, so the band
    // has to cover it. Everything below is measured from the bottom of
    // the status bar, which is what the Figma coordinates describe.
    final topInset = MediaQuery.paddingOf(context).top;
    final bandHeight =
        (topInset > figmaStatusBarHeight ? topInset : figmaStatusBarHeight) +
        bandContentHeight;

    return SizedBox(
      height: bandHeight,
      child: ColoredBox(
        color: ColorsFrave.headerYellow,
        child: Stack(
          children: <Widget>[
            // Keep the Figma-sized arrow, but provide a 48 x 48 px tap target.
            Positioned(
              left: gutter - 20,
              top: 64,
              child: Semantics(
                button: true,
                label: context.l10n.actionBack,
                child: InkWell(
                  onTap: () => goBack(context),
                  borderRadius: BorderRadius.circular(24),
                  child: const SizedBox.square(
                    dimension: 48,
                    child: Center(
                      child: Icon(
                        Icons.arrow_back_ios_new,
                        size: 13,
                        color: ColorsFrave.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Title — Figma: top y73 on the frame.
            Positioned(
              left: gutter + 20,
              right: gutter + 20,
              top: 73,
              bottom: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    context.l10n.ordersTitle,
                    maxLines: 1,
                    style: FraveText.bold(
                      28,
                      color: ColorsFrave.onOrange,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The list of orders for the current filter, or the empty state.
class _OrdersContent extends StatelessWidget {
  const _OrdersContent({required this.state});

  final OrdersState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoadingMy && state.myOrders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ColorsFrave.navOrange),
      );
    }

    if (state.myOrdersError != null && state.myOrders.isEmpty) {
      return _ErrorState(message: context.failure(state.myOrdersError!));
    }

    final orders = state.filteredMyOrders;
    if (orders.isEmpty) {
      return OrdersEmptyState(filter: state.filter);
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const Divider(
        height: 1,
        thickness: 1,
        color: ColorsFrave.dividerOrange,
      ),
      itemBuilder: (context, i) {
        final order = orders[i];
        return OrderRow(
          order: order,
          onCancel: () => _confirmCancel(context, order),
          onTrack: () => context.push('/client/map'),
        );
      },
    );
  }

  /// The cancellation flow lands in a later use-case; until then the
  /// button explains what is coming instead of mutating anything.
  void _confirmCancel(BuildContext context, OrderRecord order) {
    errorTextSnack(
      context,
      context.l10n.ordersCancelUnavailable(order.id, order.status),
    );
  }
}

/// Shown when the My Orders stream failed and we have nothing to show.
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.cloud_off_rounded,
              size: 56,
              color: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.ordersLoadFailedTitle,
              textAlign: TextAlign.center,
              style: FraveText.medium(20, color: ColorsFrave.ink),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: FraveText.regular(14, color: ColorsFrave.greyText),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () {
                final clientId = context.read<AuthBloc>().state.user?.uid;
                if (clientId == null || clientId.isEmpty) return;
                context.read<OrdersBloc>().add(OnLoadMyOrdersEvent(clientId));
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: ColorsFrave.navOrange,
                side: const BorderSide(
                  color: ColorsFrave.navOrange,
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child: Text(
                context.l10n.ordersTryAgain,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
