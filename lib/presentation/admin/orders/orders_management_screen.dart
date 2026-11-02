import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/admin_orders/admin_orders_bloc.dart';
import '../../../domain/models/admin_order_filter.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../dashboard/widgets/recent_orders.dart';

/// AdminOrdersManagementScreen — every order, with a status filter
/// (UC-09).
///
/// The list is fed by a realtime Firebase stream: an order that comes
/// in while the admin is looking at the screen appears on its own.
class AdminOrdersManagementScreen extends StatelessWidget {
  const AdminOrdersManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AdminOrdersBloc>(
      create: (context) => AdminOrdersBloc(
        ordersService: context.read<AdminOrdersService>(),
      )..add(const AdminOrdersLoadRequested()),
      child: const _AdminOrdersView(),
    );
  }
}

class _AdminOrdersView extends StatelessWidget {
  const _AdminOrdersView();

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
          context.l10n.adminOrdersTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
      ),
      body: Column(
        children: <Widget>[
          const _OrderFilterChips(),
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
                final orders = state.visibleOrders;
                if (orders.isEmpty) {
                  return const _OrdersEmpty();
                }
                return RefreshIndicator(
                  color: ColorsFrave.navOrange,
                  onRefresh: () async {
                    context
                        .read<AdminOrdersBloc>()
                        .add(const AdminOrdersRefreshRequested());
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _AdminOrderTile(order: orders[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The row of status filter chips.
class _OrderFilterChips extends StatelessWidget {
  const _OrderFilterChips();

  /// The Vietnamese label of [filter].
  static String labelFor(BuildContext context, AdminOrderFilter filter) {
    final l10n = context.l10n;
    switch (filter) {
      case AdminOrderFilter.all:
        return l10n.adminOrderFilterAll;
      case AdminOrderFilter.pending:
        return l10n.adminOrderFilterPending;
      case AdminOrderFilter.preparing:
        return l10n.adminOrderFilterPreparing;
      case AdminOrderFilter.delivering:
        return l10n.adminOrderFilterDelivering;
      case AdminOrderFilter.completed:
        return l10n.adminOrderFilterCompleted;
      case AdminOrderFilter.cancelled:
        return l10n.adminOrderFilterCancelled;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = context.select<AdminOrdersBloc, AdminOrderFilter>(
      (bloc) => bloc.state.filter,
    );

    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AdminOrderFilter.values.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final filter = AdminOrderFilter.values[index];
            final isSelected = filter == selected;
            return Material(
              color: isSelected
                  ? ColorsFrave.navOrange
                  : ColorsFrave.orangeSoft,
              borderRadius: BorderRadius.circular(100),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => context
                    .read<AdminOrdersBloc>()
                    .add(AdminOrderFilterChanged(filter)),
                child: SizedBox(
                  height: 32,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: Text(
                          labelFor(context, filter),
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
          },
        ),
      ),
    );
  }
}

/// One order row of the admin list.
class _AdminOrderTile extends StatelessWidget {
  const _AdminOrderTile({required this.order});

  final OrderRecord order;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = order.products;
    final title = items.isEmpty
        ? l10n.ordersFallbackTitle(order.id)
        : items.first.nameProduct;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Material(
      color: ColorsFrave.surfaceColor,
      borderRadius: BorderRadius.circular(RadiusFrave.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/admin/orders/${order.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
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
                    const SizedBox(height: 6),
                    Row(
                      children: <Widget>[
                        AdminStatusPill(status: order.status),
                        const SizedBox(width: 8),
                        if (order.deliveryUserName.trim().isNotEmpty)
                          Flexible(
                            child: Text(
                              order.deliveryUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FraveText.light(12, color: ColorsFrave.greyText),
                            ),
                          )
                        else
                          Flexible(
                            child: Text(
                              l10n.adminOrderNoDelivery,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: FraveText.light(12, color: ColorsFrave.lightGrey),
                            ),
                          ),
                      ],
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
        ),
      ),
    );
  }
}

/// The empty state of the admin orders list.
class _OrdersEmpty extends StatelessWidget {
  const _OrdersEmpty();

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
              context.l10n.adminOrdersEmpty,
              textAlign: TextAlign.center,
              style: FraveText.regular(15, color: ColorsFrave.greyText),
            ),
          ],
        ),
      ),
    );
  }
}
