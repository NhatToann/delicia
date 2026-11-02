import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The "recent orders" widget of the admin dashboard (UC-07).
///
/// It shows the last few orders with their status pill, the amount and
/// the time — enough for the restaurant to see what just came in
/// without leaving the dashboard.
class RecentOrders extends StatelessWidget {
  const RecentOrders({
    super.key,
    required this.orders,
    this.onViewAll,
    this.onTapOrder,
    this.maxItems = 5,
  });

  /// The orders, newest first.
  final List<OrderRecord> orders;

  /// Fired when the "view all" link is tapped.
  final VoidCallback? onViewAll;

  /// Fired when a row is tapped.
  final void Function(OrderRecord order)? onTapOrder;

  /// How many rows are shown at most.
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final visible = orders.take(maxItems).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              context.l10n.adminRecentOrdersTitle,
              style: FraveText.semiBold(18, color: ColorsFrave.ink),
            ),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                style: TextButton.styleFrom(
                  foregroundColor: ColorsFrave.navOrange,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  context.l10n.adminViewAllOrders,
                  style: FraveText.medium(14, color: ColorsFrave.navOrange),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: Text(
                context.l10n.adminRecentOrdersEmpty,
                style: FraveText.regular(14, color: ColorsFrave.greyText),
              ),
            ),
          )
        else
          ...visible.map(
            (order) => RecentOrderTile(
              order: order,
              onTap: onTapOrder == null ? null : () => onTapOrder!(order),
            ),
          ),
      ],
    );
  }
}

/// One row of the [RecentOrders] widget.
class RecentOrderTile extends StatelessWidget {
  const RecentOrderTile({super.key, required this.order, this.onTap});

  final OrderRecord order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final items = order.products;
    final title = items.isEmpty
        ? context.l10n.ordersFallbackTitle(order.id)
        : items.first.nameProduct;
    final itemCount = items.fold<int>(0, (sum, i) => sum + i.quantity);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
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
                    const SizedBox(height: 3),
                    Text(
                      context.l10n.adminProductStockCount(itemCount),
                      style: FraveText.light(13, color: ColorsFrave.greyText),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AdminStatusPill(status: order.status),
              const SizedBox(width: 10),
              Text(
                Money.format(order.amount),
                style: FraveText.medium(15, color: ColorsFrave.navOrange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The status pill used across the admin screens.
///
/// The domain only carries the stable status id; the Vietnamese label
/// is mapped here so the wording lives in exactly one place.
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({super.key, required this.status});

  /// A raw [OrderRecord.status] value.
  final String status;

  /// The Vietnamese label of [status].
  static String labelFor(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status) {
      case OrderRecord.statusPaidOut:
        return l10n.adminOrderStatusPaidOut;
      case OrderRecord.statusPreparing:
        return l10n.adminOrderStatusPreparing;
      case OrderRecord.statusDispatched:
        return l10n.adminOrderStatusDispatched;
      case OrderRecord.statusOnWay:
        return l10n.adminOrderStatusOnWay;
      case OrderRecord.statusDelivered:
        return l10n.adminOrderStatusDelivered;
      case OrderRecord.statusCancelled:
        return l10n.adminOrderStatusCancelled;
      default:
        return status;
    }
  }

  /// The colour of the pill for [status].
  static Color colorFor(String status) {
    switch (status) {
      case OrderRecord.statusPaidOut:
        return ColorsFrave.warningColor;
      case OrderRecord.statusPreparing:
        return ColorsFrave.tertiaryColor;
      case OrderRecord.statusDispatched:
        return ColorsFrave.navOrange;
      case OrderRecord.statusOnWay:
        return ColorsFrave.secondaryColor;
      case OrderRecord.statusDelivered:
        return ColorsFrave.successColor;
      case OrderRecord.statusCancelled:
        return ColorsFrave.greyText;
      default:
        return ColorsFrave.greyText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        labelFor(context, status),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: FraveText.medium(12, color: color),
      ),
    );
  }
}
