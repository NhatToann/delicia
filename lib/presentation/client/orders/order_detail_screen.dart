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
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../themes/colors_frave.dart';
import 'widgets/order_status_timeline.dart';

/// OrderDetailScreen — opens a single order and subscribes to its realtime
/// updates (UC-05).  Accepts the [OrderRecord] via `state.extra` so the
/// list can hand it over without an extra fetch, then streams the
/// up-to-date version via [ClientOrdersService.watchOrderUpdates].
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
              // Bubble the new state into the list BLoC so cancelling flow
              // stays consistent across screens.
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          // Guard against being entered through a `go()` navigation (e.g.
          // straight after checkout) where there is no previous page to pop.
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/client/orders');
            }
          },
        ),
        title: TextCustom(
          'Order #${widget.orderId.substring(0, widget.orderId.length.clamp(0, 8))}',
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: order == null
          ? const Center(
              child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
            )
          : _Loaded(order: order),
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
      padding: const EdgeInsets.all(20),
      children: [
        _Header(order: order),
        const SizedBox(height: 16),
        _SectionTitle('Delivery progress'),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ColorsFrave.backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: OrderStatusTimeline(status: order.status),
        ),
        const SizedBox(height: 20),
        _SectionTitle('Items'),
        ...order.products.map((p) => _ItemTile(item: p)),
        const SizedBox(height: 16),
        _SectionTitle('Payment & delivery'),
        _SummaryCard(order: order, subtotal: subtotal),
        const SizedBox(height: 20),
        BlocBuilder<ClientOrdersBloc, ClientOrdersState>(
          buildWhen: (a, b) => a.cancellingOrderId != b.cancellingOrderId,
          builder: (_, state) {
            final canCancel = isOrderCancellable(order.status);
            if (!canCancel) return const SizedBox.shrink();
            final cancelling = state.cancellingOrderId == order.id;
            final uid = context.read<AuthBloc>().state.user?.uid ?? '';
            return BtnFrave(
              text: cancelling ? 'Cancelling…' : 'Cancel this order',
              color: ColorsFrave.errorColor,
              onPressed: cancelling
                  ? null
                  : () => _confirmCancel(context, uid, order.id),
            );
          },
        ),
        const SizedBox(height: 12),
        BtnFrave(
          text: 'Open live tracking',
          color: Colors.white,
          textColor: ColorsFrave.primaryColor,
          onPressed: () => _openTracking(context, order),
        ),
        const SizedBox(height: 24),
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
      builder: (_) => AlertDialog(
        title: const TextCustom(
          'Cancel this order?',
          fontWeight: FontWeight.bold,
        ),
        content: const TextCustom(
          'Once cancelled, the order can no longer be reversed.',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TextCustom('Keep order', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel order'),
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

class _Header extends StatelessWidget {
  final OrderRecord order;
  const _Header({required this.order});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: ColorsFrave.backgroundColor,
            child: Icon(Icons.receipt_long, color: ColorsFrave.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextCustom(
                  relativeOrderTime(order.createdAt),
                  color: ColorsFrave.greyText,
                  fontSize: 13,
                ),
                const SizedBox(height: 4),
                OrderStatusBadge(status: order.status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final OrderItem item;
  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
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
              children: [
                TextCustom(
                  item.nameProduct.isEmpty
                      ? 'Product ${item.productId}'
                      : item.nameProduct,
                  fontWeight: FontWeight.w600,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                TextCustom(
                  '${item.quantity} × \$${item.price.toStringAsFixed(2)}',
                  color: ColorsFrave.greyText,
                  fontSize: 13,
                ),
              ],
            ),
          ),
          TextCustom(
            '\$${(item.price * item.quantity).toStringAsFixed(2)}',
            fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorsFrave.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('Items', '${order.products.length}'),
          _row('Subtotal', '\$${subtotal.toStringAsFixed(2)}'),
          _row('Total', '\$${order.amount.toStringAsFixed(2)}', bold: true),
          const Divider(),
          _row('Payment method', order.paymentMethod),
          if (order.street.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextCustom('Delivery address', fontWeight: FontWeight.bold),
            const SizedBox(height: 4),
            TextCustom(order.street),
            if (order.reference.isNotEmpty)
              TextCustom(
                order.reference,
                color: ColorsFrave.greyText,
                fontSize: 13,
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextCustom(
            label,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            color: bold ? ColorsFrave.darkText : ColorsFrave.greyText,
          ),
          TextCustom(
            value,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: TextCustom(text, fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}
