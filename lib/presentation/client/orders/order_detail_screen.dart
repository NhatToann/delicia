import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/client_orders/client_orders_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart'
    show OrdersBloc, OnTrackOrderEvent;
import '../../../domain/models/order_item.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/client_orders_service.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'widgets/order_status_timeline.dart';

/// OrderDetailScreen — opens a single order and subscribes to its realtime
/// updates (UC-05).  Accepts the [OrderRecord] via `state.extra` so the
/// list can hand it over without an extra fetch, then streams the
/// up-to-date version via [ClientOrdersService.watchOrderUpdates].
///
/// The screen uses the same yellow header band and the same orange tokens
/// as the Figma "My Orders" frames, so the two screens read as one flow.
class OrderDetailScreen extends StatefulWidget {
  final String orderId;
  final OrderRecord? initialOrder;

  const OrderDetailScreen({
    super.key,
    required this.orderId,
    this.initialOrder,
  });

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late final ClientOrdersService _ordersService;
  StreamSubscription<OrderRecord?>? _sub;
  OrderRecord? _live;

  @override
  void initState() {
    super.initState();
    _live = widget.initialOrder;
    _ordersService = context.read<ClientOrdersService>();
    _sub = _ordersService
        .watchOrderUpdates(widget.orderId)
        .listen(
          (record) {
            if (!mounted) return;
            setState(() => _live = record);
            if (record != null) {
              // Bubble the new state into the list BLoC so the list stays
              // consistent with the detail screen.
              context.read<ClientOrdersBloc>().add(
                OnLoadClientOrdersEvent(
                  clientId: context.read<AuthBloc>().state.user?.uid ?? '',
                ),
              );
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            errorTextSnack(context, 'Live updates unavailable: $e');
          },
          cancelOnError: false,
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final order = _live;
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: Column(
        children: <Widget>[
          FigmaHeaderBand(
            title: context.l10n.ordersDetailTitle,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client/orders');
              }
            },
          ),
          Expanded(
            child: order == null
                ? const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  )
                : _Loaded(order: order),
          ),
        ],
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  final OrderRecord order;

  const _Loaded({required this.order});

  @override
  Widget build(BuildContext context) {
    final subtotal = order.products.fold<double>(
      0,
      (s, p) => s + (p.price * p.quantity),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(35, 24, 35, 32),
      children: <Widget>[
        _Header(order: order),
        const SizedBox(height: 24),
        _SectionTitle(context.l10n.ordersDetailProgress),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(RadiusFrave.card),
          ),
          child: OrderStatusTimeline(status: order.status),
        ),
        const SizedBox(height: 24),
        _SectionTitle(context.l10n.ordersDetailItems),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(RadiusFrave.card),
          ),
          child: order.products.isEmpty
              ? Text(
                  context.l10n.ordersEmptyActiveTitle,
                  style: FraveText.regular(14, color: ColorsFrave.greyText),
                )
              : Column(
                  children: <Widget>[
                    for (final product in order.products)
                      _ItemTile(item: product),
                  ],
                ),
        ),
        const SizedBox(height: 24),
        _SectionTitle(context.l10n.ordersDetailSummary),
        const SizedBox(height: 12),
        _SummaryCard(order: order, subtotal: subtotal),
        const SizedBox(height: 24),
        BlocBuilder<ClientOrdersBloc, ClientOrdersState>(
          buildWhen: (a, b) => a.cancellingOrderId != b.cancellingOrderId,
          builder: (_, state) {
            final canCancel = isOrderCancellable(order.status);
            if (!canCancel) return const SizedBox.shrink();
            final cancelling = state.cancellingOrderId == order.id;
            final uid = context.read<AuthBloc>().state.user?.uid ?? '';
            return _PillButton(
              label: cancelling
                  ? context.l10n.ordersDetailCancelling
                  : context.l10n.ordersDetailCancel,
              background: ColorsFrave.errorColor,
              foreground: ColorsFrave.onOrange,
              icon: Icons.cancel_outlined,
              onPressed: cancelling
                  ? null
                  : () => _confirmCancel(context, uid, order.id),
            );
          },
        ),
        const SizedBox(height: 12),
        _PillButton(
          label: context.l10n.ordersDetailTrack,
          background: ColorsFrave.navOrange,
          foreground: ColorsFrave.onOrange,
          icon: Icons.location_on_outlined,
          onPressed: () => _openTracking(context, order),
        ),
      ],
    );
  }

  /// Publishes the order to the shared [OrdersBloc] before opening the map.
  ///
  /// The map reads `OrdersBloc.state.lastOrder`, which is normally set by
  /// the checkout flow.  Opening the map from the order history has to hand
  /// the order over explicitly, otherwise the map has nothing to centre on.
  void _openTracking(BuildContext context, OrderRecord order) {
    context.read<OrdersBloc>().add(OnTrackOrderEvent(order));
    context.push('/client/map');
  }

  Future<void> _confirmCancel(
    BuildContext context,
    String uid,
    String orderId,
  ) async {
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
    if (confirmed == true && context.mounted) {
      context.read<ClientOrdersBloc>().add(
        OnCancelOrderEvent(clientId: uid, orderId: orderId),
      );
    }
  }
}

/// The order summary card: id, time, status and total.
class _Header extends StatelessWidget {
  final OrderRecord order;

  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 8),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: ColorsFrave.orangeSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long,
              color: ColorsFrave.navOrange,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.ordersOrderNumber(_shortId(order.id)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.bold(18, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  relativeOrderTime(order.createdAt),
                  style: FraveText.regular(13, color: ColorsFrave.greyText),
                ),
              ],
            ),
          ),
          OrderStatusBadge(status: order.status),
        ],
      ),
    );
  }

  static String _shortId(String id) => id.length <= 8 ? id : id.substring(0, 8);
}

class _ItemTile extends StatelessWidget {
  final OrderItem item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 56,
              height: 56,
              child: ImageResolver.resolveWidget(
                item.picture,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  item.nameProduct.isEmpty
                      ? 'Product ${item.productId}'
                      : item.nameProduct,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(15, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item.quantity} × ${Money.format(item.price)}',
                  style: FraveText.regular(13, color: ColorsFrave.greyText),
                ),
              ],
            ),
          ),
          Text(
            Money.format(item.price * item.quantity),
            style: FraveText.semiBold(15, color: ColorsFrave.ink),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final OrderRecord order;
  final double subtotal;

  const _SummaryCard({required this.order, required this.subtotal});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _row(
            context,
            context.l10n.ordersDetailItems,
            Money.format(subtotal),
          ),
          const SizedBox(height: 6),
          _row(
            context,
            context.l10n.ordersDetailTotal,
            Money.format(order.amount),
            bold: true,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(
              height: 1,
              thickness: 1,
              color: ColorsFrave.dividerOrange,
            ),
          ),
          _row(
            context,
            context.l10n.ordersDetailPaymentMethod,
            order.paymentMethod,
          ),
          if (order.street.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              context.l10n.ordersDetailAddress,
              style: FraveText.medium(14, color: ColorsFrave.ink),
            ),
            const SizedBox(height: 4),
            Text(
              order.street,
              style: FraveText.regular(14, color: ColorsFrave.greyText),
            ),
            if (order.reference.isNotEmpty)
              Text(
                order.reference,
                style: FraveText.regular(13, color: ColorsFrave.greyText),
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Flexible(
          child: Text(
            label,
            style: bold
                ? FraveText.semiBold(14, color: ColorsFrave.ink)
                : FraveText.regular(14, color: ColorsFrave.greyText),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: bold
              ? FraveText.bold(16, color: ColorsFrave.navOrange)
              : FraveText.medium(14, color: ColorsFrave.ink),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: FraveText.bold(18, color: ColorsFrave.ink),
    );
  }
}

/// A full-width stadium button used for the primary / secondary actions.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.8),
          elevation: 0,
          shape: const StadiumBorder(),
        ),
        icon: Icon(icon, size: 18),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            style: FraveText.semiBold(15, color: foreground),
          ),
        ),
      ),
    );
  }
}
