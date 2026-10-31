import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/client_orders/client_orders_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart'
    show OrdersBloc, OnTrackOrderEvent;
import '../../../domain/models/order_filter.dart';
import '../../../domain/models/order_record.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'widgets/order_filter_chips.dart';
import 'widgets/order_row.dart';
import 'widgets/orders_empty_state.dart';

/// OrdersListScreen — the client's order history (UC-05).
///
/// Figma frames:
///   147:2153 — "4.1.1 - B - My Orders"        (empty state)
///   147:2106 — "4.1.1 - C - My Orders - Active" (one order)
///
/// Layout on a 393 x 852 frame:
///
///   status bar   h32, fill #F5CB58
///   back arrow   x35  y81   8 x 13
///   title        "My Orders" centred, League Spartan Bold 28 #F8F8F8
///   filter chips y164  h28   Active / Completed / Cancelled
///   content      y211+  (hairline dividers, 323 px wide)
///
/// The screen is driven by [ClientOrdersBloc], which
///
///   * loads and streams the client's orders in realtime,
///   * slices them by the selected [OrderFilter],
///   * cancels an order that is still cancellable.
///
/// Tapping a row opens the order-detail screen, which keeps streaming that
/// single order's updates.
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> {
  /// The chip the user last tapped. Defaults to "Active".
  OrderFilter _filter = OrderFilter.active;

  /// The uid whose orders are currently displayed. Used to reload the list
  /// when the account changes (sign-in / sign-out / account switch).
  String? _loadedUid;

  /// Guards against double-loading while the first frame is still settling.
  bool _loading = false;

  @override
  void dispose() {
    _loading = false;
    super.dispose();
  }

  /// Loads (and subscribes to) the orders of [uid].
  void _loadFor(String uid) {
    if (uid.isEmpty) return;
    final bloc = context.read<ClientOrdersBloc>();
    bloc.add(OnLoadClientOrdersEvent(clientId: uid));
    bloc.add(OnSubscribeClientOrdersEvent(clientId: uid));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthBloc>().state;
    final uid = auth.user?.uid ?? '';

    // React to the account: load once per uid, and wipe the list when the
    // user signs out so the next account never sees the previous orders.
    if (uid.isNotEmpty && _loadedUid != uid) {
      _loadedUid = uid;
      if (!_loading) {
        _loading = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _loading = false;
          _loadFor(uid);
        });
      }
    } else if (uid.isEmpty && _loadedUid != null) {
      _loadedUid = null;
    }

    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: Column(
        children: <Widget>[
          FigmaHeaderBand(
            title: context.l10n.ordersTitle,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client/home');
              }
            },
            actions: <Widget>[
              BlocBuilder<ClientOrdersBloc, ClientOrdersState>(
                buildWhen: (a, b) =>
                    a.realtimeActive != b.realtimeActive ||
                    a.isLoading != b.isLoading,
                builder: (context, state) {
                  return IconButton(
                    tooltip: state.realtimeActive
                        ? context.l10n.ordersLiveUpdatesOn
                        : context.l10n.ordersLiveUpdatesOff,
                    icon: Icon(
                      state.realtimeActive
                          ? Icons.wifi_tethering
                          : Icons.refresh,
                      color: ColorsFrave.ink,
                    ),
                    onPressed: () {
                      if (uid.isEmpty) {
                        errorTextSnack(
                          context,
                          context.l10n.ordersSignInToRefresh,
                        );
                        return;
                      }
                      context.read<ClientOrdersBloc>().add(
                        OnRefreshClientOrdersEvent(clientId: uid),
                      );
                    },
                  );
                },
              ),
            ],
          ),
          Expanded(
            child: BlocConsumer<ClientOrdersBloc, ClientOrdersState>(
              listenWhen: (a, b) =>
                  a.error != b.error || a.lastUpdatedOrder != b.lastUpdatedOrder,
              listener: (context, state) {
                if (state.error != null) {
                  errorTextSnack(context, state.error!);
                } else if (state.lastUpdatedOrder != null) {
                  final order = state.lastUpdatedOrder!;
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.ordersCancelledToast(
                            _shortId(order.id),
                          ),
                        ),
                        backgroundColor: ColorsFrave.successColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                }
              },
              builder: (context, state) {
                // Figma: the chip row starts at y164, the header band ends
                // at y129 → 35 px of gap.
                return Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.only(top: 35, bottom: 20),
                      child: OrderFilterChips(
                        selected: _filter,
                        onSelected: (filter) =>
                            setState(() => _filter = filter),
                      ),
                    ),
                    Expanded(child: _OrdersBody(state: state, filter: _filter)),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppNavDestination.orders,
        onTap: (index) => AppNavDestination.go(context, index),
      ),
    );
  }

  /// The short, human-readable order id shown in the UI.
  static String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}

/// The list of orders for the selected filter, or the empty state.
class _OrdersBody extends StatelessWidget {
  const _OrdersBody({required this.state, required this.filter});

  final ClientOrdersState state;
  final OrderFilter filter;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ColorsFrave.navOrange),
      );
    }

    if (state.error != null && state.orders.isEmpty) {
      return _ErrorState(message: state.error!);
    }

    final orders = state.orders.where(filter.accepts).toList(growable: false);
    if (orders.isEmpty) {
      return OrdersEmptyState(filter: filter);
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
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
          onTap: () => context.push(
            '/client/orders/detail/${order.id}',
            extra: order,
          ),
          onCancel: () => _confirmCancel(context, order),
          onTrack: () => _trackOrder(context, order),
        );
      },
    );
  }

  /// Asks for confirmation, then hands the cancellation to the bloc.
  ///
  /// The bloc owns the rule ("only a PAID OUT order can be cancelled"), so
  /// the dialog is purely a confirmation step — a stale list can never
  /// cancel an order the server would refuse.
  Future<void> _confirmCancel(BuildContext context, OrderRecord order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.sheet),
        ),
        title: Text(
          context.l10n.ordersCancelTitle,
          style: FraveText.bold(20, color: ColorsFrave.ink),
        ),
        content: Text(
          context.l10n.ordersCancelBody,
          style: FraveText.regular(14, color: ColorsFrave.greyText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.ordersCancelKeep,
              style: FraveText.medium(14, color: ColorsFrave.greyText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorsFrave.navOrange,
              foregroundColor: ColorsFrave.onOrange,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.ordersCancelConfirm,
              style: FraveText.medium(14, color: ColorsFrave.onOrange),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    context.read<ClientOrdersBloc>().add(
      OnCancelOrderEvent(clientId: uid, orderId: order.id),
    );
  }

  /// Publishes the order to the shared [OrdersBloc] before opening the map,
  /// so the live-tracking screen knows which order to follow.
  void _trackOrder(BuildContext context, OrderRecord order) {
    context.read<OrdersBloc>().add(OnTrackOrderEvent(order));
    context.push('/client/map');
  }
}

/// Shown when the orders could not be loaded and there is nothing to show.
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
                final uid = context.read<AuthBloc>().state.user?.uid ?? '';
                if (uid.isEmpty) return;
                context.read<ClientOrdersBloc>().add(
                  OnRefreshClientOrdersEvent(clientId: uid),
                );
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
                style: FraveText.medium(14, color: ColorsFrave.navOrange),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
