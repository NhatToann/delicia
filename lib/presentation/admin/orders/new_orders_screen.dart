import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../domain/bloc/admin_orders/admin_orders_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../dashboard/widgets/recent_orders.dart';

/// AdminNewOrdersScreen — the orders customers just placed (UC-07 / UC-09).
///
/// The dashboard's "Đơn hàng mới" tile counts the orders that came in
/// today. Tapping it lands here, where the restaurant sees *who* ordered
/// what, when, and how much — so a fresh order can be picked up without
/// digging through the full order list.
///
/// The screen is fed by the same realtime stream as the admin orders
/// list: an order that comes in while the screen is open shows up on
/// its own.
class AdminNewOrdersScreen extends StatelessWidget {
  const AdminNewOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminOrdersBloc>(
      create: (context) => AdminOrdersBloc(
        ordersService: context.read<AdminOrdersService>(),
      )..add(const AdminOrdersLoadRequested()),
      child: const _AdminNewOrdersView(),
    );
  }
}

class _AdminNewOrdersView extends StatefulWidget {
  const _AdminNewOrdersView();

  @override
  State<_AdminNewOrdersView> createState() => _AdminNewOrdersViewState();
}

class _AdminNewOrdersViewState extends State<_AdminNewOrdersView> {
  /// Whether the list shows only today's orders or the whole history.
  bool _todayOnly = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      appBar: AppBar(
        backgroundColor: ColorsFrave.navOrange,
        foregroundColor: ColorsFrave.onOrange,
        elevation: 0,
        leading: IconButton(
          onPressed: () => goBack(context, fallback: '/admin/home'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          context.l10n.adminNewOrdersTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: BlocConsumer<AdminOrdersBloc, AdminOrdersState>(
              listenWhen: (previous, current) =>
                  previous.error != current.error && current.error != null,
              listener: (context, state) {
                errorMessageSnack(context, state.error!);
              },
              builder: (context, state) {
                if (state.isLoading && state.orders.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  );
                }
                final orders = _visible(state.orders);
                return Column(
                  children: <Widget>[
                    _RangeToggle(
                      todayOnly: _todayOnly,
                      todayCount: _todayCount(state.orders),
                      onChanged: (value) =>
                          setState(() => _todayOnly = value),
                    ),
                    Expanded(
                      child: orders.isEmpty
                          ? const _NewOrdersEmpty()
                          : RefreshIndicator(
                              color: ColorsFrave.navOrange,
                              onRefresh: () async {
                                context.read<AdminOrdersBloc>().add(
                                      const AdminOrdersRefreshRequested(),
                                    );
                              },
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  8,
                                  16,
                                  32,
                                ),
                                itemCount: orders.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) =>
                                    _NewOrderTile(order: orders[index]),
                              ),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// The orders the current range shows.
  ///
  /// "Today" is computed the same way the dashboard computes it, so the
  /// number on the tile and the number of rows here always agree.
  List<OrderRecord> _visible(List<OrderRecord> orders) {
    if (!_todayOnly) return orders;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return orders
        .where((o) => !o.createdAt.isBefore(start) && o.createdAt.isBefore(end))
        .toList(growable: false);
  }

  /// How many orders came in today.
  int _todayCount(List<OrderRecord> orders) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return orders
        .where((o) => !o.createdAt.isBefore(start) && o.createdAt.isBefore(end))
        .length;
  }
}

/// The "hôm nay" / "tất cả" switch above the list.
class _RangeToggle extends StatelessWidget {
  const _RangeToggle({
    required this.todayOnly,
    required this.todayCount,
    required this.onChanged,
  });

  final bool todayOnly;
  final int todayCount;
  final void Function(bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: <Widget>[
          _ToggleChip(
            label: context.l10n.adminNewOrdersTodayCount(todayCount),
            isSelected: todayOnly,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 8),
          _ToggleChip(
            label: context.l10n.adminNewOrdersAllTime,
            isSelected: !todayOnly,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? ColorsFrave.navOrange : ColorsFrave.orangeSoft,
      borderRadius: BorderRadius.circular(100),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 32,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  label,
                  maxLines: 1,
                  style: isSelected
                      ? FraveText.medium(13, color: ColorsFrave.onOrange)
                      : FraveText.regular(13, color: ColorsFrave.navOrange),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One order row of the "new orders" list.
class _NewOrderTile extends StatelessWidget {
  const _NewOrderTile({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = order.products;
    final title = items.isEmpty
        ? l10n.ordersFallbackTitle(order.id)
        : items.first.nameProduct;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final customer = order.clientName.trim().isEmpty
        ? l10n.adminOrderCustomerUnknown
        : order.clientName.trim();

    return Material(
      color: ColorsFrave.surfaceColor,
      borderRadius: BorderRadius.circular(RadiusFrave.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/admin/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: FraveText.medium(16, color: ColorsFrave.ink),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.adminProductStockCount(itemCount),
                          style: FraveText.light(13, color: ColorsFrave.greyText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    Money.format(order.amount),
                    style: FraveText.medium(16, color: ColorsFrave.navOrange),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  AdminStatusPill(status: order.status),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _placedAtLabel(order.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FraveText.light(12, color: ColorsFrave.greyText),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: ColorsFrave.dividerOrange, height: 1),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.person_outline_rounded,
                    size: 16,
                    color: ColorsFrave.navOrange,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FraveText.medium(13, color: ColorsFrave.ink),
                    ),
                  ),
                  if (order.clientEmail.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        order.clientEmail.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FraveText.light(12, color: ColorsFrave.greyText),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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
    return isToday ? time : '${DateFormat('dd/MM HH:mm').format(createdAt)}';
  }
}

/// The empty state of the "new orders" list.
class _NewOrdersEmpty extends StatelessWidget {
  const _NewOrdersEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.receipt_long_outlined,
              size: 56,
              color: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.adminNewOrdersEmpty,
              textAlign: TextAlign.center,
              style: FraveText.regular(15, color: ColorsFrave.greyText),
            ),
          ],
        ),
      ),
    );
  }
}
