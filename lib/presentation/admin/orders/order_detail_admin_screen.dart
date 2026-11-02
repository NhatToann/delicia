import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../domain/bloc/admin_orders/admin_orders_bloc.dart';
import '../../../domain/bloc/delivery/delivery_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../dashboard/widgets/recent_orders.dart';
import 'widgets/assign_delivery_dialog.dart';

/// AdminOrderDetailScreen — one order, in full (UC-09).
///
/// The screen shows the order lines, the amount and the fulfilment
/// actions the admin can take from here: start preparing, assign a
/// courier, mark it delivered.
class AdminOrderDetailScreen extends StatelessWidget {
  const AdminOrderDetailScreen({super.key, required this.orderId});

  /// The id of the order to show.
  final String orderId;

  @override
  Widget build(BuildContext context) {
    // The detail screen is pushed as its own route, so it cannot rely on
    // the list screen's bloc — it opens its own.
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AdminOrdersBloc>(
          create: (context) => AdminOrdersBloc(
            ordersService: context.read<AdminOrdersService>(),
          )..add(const AdminOrdersLoadRequested()),
        ),
        BlocProvider<DeliveryBloc>(
          create: (context) => DeliveryBloc(
            deliveryUsersService: context.read<DeliveryUsersService>(),
          )..add(const DeliveryUsersLoadRequested()),
        ),
      ],
      child: _AdminOrderDetailView(orderId: orderId),
    );
  }
}

class _AdminOrderDetailView extends StatelessWidget {
  const _AdminOrderDetailView({required this.orderId});

  final String orderId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminOrdersBloc, AdminOrdersState>(
      builder: (context, state) {
        final order = state.orders
            .where((o) => o.id == orderId)
            .cast<OrderRecord?>()
            .firstWhere((_) => true, orElse: () => null);

        return Scaffold(
          backgroundColor: ColorsFrave.pageBg,
          appBar: AppBar(
            backgroundColor: ColorsFrave.navOrange,
            foregroundColor: ColorsFrave.onOrange,
            elevation: 0,
            leading: IconButton(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            ),
            title: Text(
              context.l10n.adminOrderDetailTitle,
              style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
            ),
          ),
          body: order == null
              ? Center(
                  child: Text(
                    context.l10n.adminOrdersEmpty,
                    style: FraveText.regular(15, color: ColorsFrave.greyText),
                  ),
                )
              : _OrderDetailBody(order: order),
        );
      },
    );
  }
}

/// The body of the detail screen.
class _OrderDetailBody extends StatefulWidget {
  const _OrderDetailBody({required this.order});

  final OrderRecord order;

  @override
  State<_OrderDetailBody> createState() => _OrderDetailBodyState();
}

class _OrderDetailBodyState extends State<_OrderDetailBody> {
  OrderRecord get order => widget.order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: <Widget>[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(RadiusFrave.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.adminOrderId,
                    style: FraveText.light(13, color: ColorsFrave.greyText),
                  ),
                  AdminStatusPill(status: order.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                order.id,
                style: FraveText.medium(16, color: ColorsFrave.ink),
              ),
              const SizedBox(height: 16),
              _InfoRow(
                label: l10n.adminOrderAddress,
                value: order.street,
              ),
              _InfoRow(
                label: l10n.adminOrderPaymentMethod,
                value: order.paymentMethod,
              ),
              _InfoRow(
                label: l10n.adminOrderCustomer,
                value: order.clientName.trim().isEmpty
                    ? l10n.adminOrderCustomerUnknown
                    : order.clientName.trim(),
              ),
              if (order.clientEmail.trim().isNotEmpty)
                _InfoRow(
                  label: l10n.adminOrderCustomerEmail,
                  value: order.clientEmail.trim(),
                ),
              _InfoRow(
                label: l10n.adminOrderDeliveryUser,
                value: order.deliveryUserName.trim().isEmpty
                    ? l10n.adminOrderNoDelivery
                    : order.deliveryUserName,
              ),
              _InfoRow(
                label: l10n.adminOrderPlacedAt,
                value: _placedAtLabel(order.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: ColorsFrave.surfaceColor,
            borderRadius: BorderRadius.circular(RadiusFrave.card),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                l10n.adminOrderItems,
                style: FraveText.semiBold(16, color: ColorsFrave.ink),
              ),
              const SizedBox(height: 10),
              for (final item in order.products)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${item.quantity} × ${item.nameProduct}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FraveText.regular(
                            14,
                            color: ColorsFrave.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        Money.format(item.price * item.quantity),
                        style: FraveText.medium(
                          14,
                          color: ColorsFrave.navOrange,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(color: ColorsFrave.dividerOrange),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    l10n.adminOrderTotal,
                    style: FraveText.medium(15, color: ColorsFrave.ink),
                  ),
                  Text(
                    Money.format(order.amount),
                    style: FraveText.bold(17, color: ColorsFrave.navOrange),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _OrderActions(order: order, onAssign: _assignDelivery),
      ],
    );
  }

  /// "14:32" for today, "12/11 14:32" for another day.
  static String _placedAtLabel(DateTime createdAt) {
    final now = DateTime.now();
    final isToday =
        createdAt.year == now.year &&
        createdAt.month == now.month &&
        createdAt.day == now.day;
    final time = DateFormat('HH:mm').format(createdAt);
    return isToday ? time : DateFormat('dd/MM HH:mm').format(createdAt);
  }

  Future<void> _assignDelivery() async {
    final l10n = context.l10n;
    final bloc = context.read<AdminOrdersBloc>();
    final drivers = context.read<DeliveryBloc>().state.users;

    final driver = await AssignDeliveryDialog.show(
      context,
      order: order,
      drivers: drivers,
      onAssign: (chosen) {
        bloc.add(
          AdminOrderAssignDeliveryRequested(
            orderId: order.id,
            deliveryUserId: chosen.uid,
            deliveryUserName: chosen.name,
          ),
        );
      },
    );

    if (driver == null || !mounted) return;
    successSnack(context, l10n.adminOrderDeliveryAssigned(driver.name));
  }
}

/// The fulfilment actions of the detail screen.
class _OrderActions extends StatelessWidget {
  const _OrderActions({required this.order, required this.onAssign});

  final OrderRecord order;
  final Future<void> Function() onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bloc = context.read<AdminOrdersBloc>();

    return Column(
      children: <Widget>[
        if (order.canStartPreparing)
          _ActionButton(
            label: l10n.adminOrderStartPreparing,
            icon: Icons.soup_kitchen_outlined,
            isFilled: true,
            onPressed: () {
              bloc.add(
                AdminOrderStatusUpdateRequested(
                  orderId: order.id,
                  status: OrderRecord.statusPreparing,
                ),
              );
            },
          ),
        if (order.canAssignDelivery) ...<Widget>[
          const SizedBox(height: 10),
          _ActionButton(
            label: order.deliveryUserId.trim().isEmpty
                ? l10n.adminOrderAssignDelivery
                : l10n.adminOrderReassignDelivery,
            icon: Icons.delivery_dining_outlined,
            isFilled: false,
            onPressed: () {
              onAssign();
            },
          ),
        ],
        if (order.canComplete) ...<Widget>[
          const SizedBox(height: 10),
          _ActionButton(
            label: l10n.adminOrderMarkDelivered,
            icon: Icons.check_circle_outline,
            isFilled: true,
            onPressed: () {
              bloc.add(
                AdminOrderStatusUpdateRequested(
                  orderId: order.id,
                  status: OrderRecord.statusDelivered,
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

/// One action button of the detail screen.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.isFilled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool isFilled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = isFilled ? ColorsFrave.onOrange : ColorsFrave.navOrange;
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icon, size: 18, color: foreground),
        const SizedBox(width: 8),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: isFilled
                  ? FraveText.medium(15, color: foreground)
                  : FraveText.regular(15, color: foreground),
            ),
          ),
        ),
      ],
    );

    if (isFilled) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: ColorsFrave.navOrange,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.button),
            ),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: ColorsFrave.navOrange,
          side: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.button),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// One labelled row of the detail card.
class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: FraveText.light(13, color: ColorsFrave.greyText),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: FraveText.regular(14, color: ColorsFrave.ink),
            ),
          ),
        ],
      ),
    );
  }
}
