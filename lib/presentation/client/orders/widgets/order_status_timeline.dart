import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../../domain/services/client_orders_service.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// OrderStatusTimeline — visual representation of an order's delivery
/// progress (UC-05).  Rendered as a vertical list of steps with an
/// active / done indicator so the user can see how far the delivery has
/// progressed at a glance.
///
/// The steps come from [ClientOrderStatuses.timeline] and are rendered with
/// the Vietnamese copy from the ARB file, so the timeline never leaks the
/// raw database status strings into the UI.
class OrderStatusTimeline extends StatelessWidget {
  final String status;

  /// Optional override of the canonical ordered list of statuses.  Used by
  /// tests so we don't depend on the production status strings.
  final List<String> orderedStatuses;

  /// Optional current index override — useful when the server status
  /// isn't in [ClientOrderStatuses.timeline] (e.g. legacy data).
  final int? currentIndexOverride;

  const OrderStatusTimeline({
    super.key,
    required this.status,
    this.orderedStatuses = const [],
    this.currentIndexOverride,
  });

  @override
  Widget build(BuildContext context) {
    final steps = orderedStatuses.isNotEmpty
        ? orderedStatuses
        : ClientOrderStatuses.timeline;
    int currentIndex =
        currentIndexOverride ??
        steps.indexWhere(
          (s) => _normalizeStatus(s) == _normalizeStatus(status),
        );
    if (currentIndex < 0) currentIndex = steps.length - 1;
    final isCancelled = _normalizeStatus(status) == 'CANCELLED';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < steps.length; i++)
          _StepRow(
            label: orderStatusLabel(context, steps[i]),
            description: orderStatusDescription(context, steps[i]),
            isDone: !isCancelled && i < currentIndex,
            isActive: !isCancelled && i == currentIndex,
            isLast: i == steps.length - 1,
            key: ValueKey('timeline-${steps[i]}'),
          ),
        if (isCancelled)
          _StepRow(
            label: context.l10n.ordersStatusCancelled,
            description: context.l10n.ordersCancelBody,
            isDone: false,
            isActive: true,
            isLast: true,
            cancelled: true,
            key: const ValueKey('timeline-cancelled'),
          ),
      ],
    );
  }

  static String _normalizeStatus(String s) => s.trim().toUpperCase();
}

/// The Vietnamese label of a raw order status.
///
/// The database stores machine strings (`PAID OUT`, `ON WAY`, …); the user
/// only ever reads the Vietnamese wording.
String orderStatusLabel(BuildContext context, String status) {
  switch (status.trim().toUpperCase()) {
    case OrderRecord.statusPaidOut:
      return context.l10n.stagePlaced;
    case OrderRecord.statusDispatched:
      return context.l10n.stageDispatched;
    case OrderRecord.statusOnWay:
      return context.l10n.stageOnTheWay;
    case OrderRecord.statusDelivered:
      return context.l10n.stageDelivered;
    case OrderRecord.statusCancelled:
      return context.l10n.ordersStatusCancelled;
    default:
      return status;
  }
}

/// The Vietnamese description of a raw order status.
String orderStatusDescription(BuildContext context, String status) {
  switch (status.trim().toUpperCase()) {
    case OrderRecord.statusPaidOut:
      return context.l10n.stagePlacedDescription;
    case OrderRecord.statusDispatched:
      return context.l10n.stageDispatchedDescription;
    case OrderRecord.statusOnWay:
      return context.l10n.stageOnTheWayDescription;
    case OrderRecord.statusDelivered:
      return context.l10n.stageDeliveredDescription;
    default:
      return '';
  }
}

class _StepRow extends StatelessWidget {
  final String label;
  final String description;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final bool cancelled;

  const _StepRow({
    super.key,
    required this.label,
    required this.description,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    this.cancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = cancelled
        ? ColorsFrave.errorColor
        : ColorsFrave.navOrange;
    final dot = isActive
        ? accent
        : isDone
        ? accent
        : ColorsFrave.orangeSoft;
    final border = isDone || isActive ? accent : ColorsFrave.orangeSoft;
    final textColor = isDone || isActive || cancelled
        ? ColorsFrave.ink
        : ColorsFrave.greyText;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: border, width: 2),
                  ),
                  child: isDone
                      ? const Icon(Icons.check, size: 10, color: ColorsFrave.onOrange)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone
                          ? ColorsFrave.navOrange
                          : ColorsFrave.orangeSoft,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 0, bottom: isLast ? 0 : 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: FraveText.medium(
                    15,
                    color: textColor,
                    height: 1.2,
                  ),
                ),
                if (description.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: FraveText.light(
                      12,
                      color: ColorsFrave.greyText,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tiny helper for OrderStatusTimeline consumers to ask whether a status
/// is user-cancellable.  We expose it on this widget file so screens
/// don't have to import the service abstraction.
bool isOrderCancellable(String status) =>
    ClientOrderStatuses.cancellableStatuses.contains(status);

/// The fill / foreground pair a status is rendered with.
///
/// Shared by the order-row ribbon and the [OrderStatusBadge] pill so both
/// always agree on the colour of a status.
({Color background, Color foreground}) orderStatusColors(String status) {
  final normalized = status.trim().toUpperCase();
  switch (normalized) {
    case 'PAID OUT':
      return (
        background: ColorsFrave.navOrange,
        foreground: ColorsFrave.onOrange,
      );
    case 'DISPATCHED':
    case 'ON WAY':
      return (
        background: ColorsFrave.orangeSoft,
        foreground: ColorsFrave.navOrange,
      );
    case 'DELIVERED':
      return (
        background: ColorsFrave.pillYellow,
        foreground: ColorsFrave.ink,
      );
    case 'CANCELLED':
      return (
        background: ColorsFrave.errorColor,
        foreground: ColorsFrave.onOrange,
      );
    default:
      return (
        background: ColorsFrave.orangeSoft,
        foreground: ColorsFrave.navOrange,
      );
  }
}

/// Compact summary used by the order-list cards.  Reuses the canonical
/// status strings so widget tests can assert against the same shape the
/// production code uses.
class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = orderStatusColors(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        orderStatusLabel(context, status),
        style: FraveText.medium(12, color: colors.foreground, height: 1.0),
      ),
    );
  }
}

/// Helper to convert a [DateTime] to a short label for cards.  Defined
/// here (vs. in DateCustom) so this widget file doesn't depend on the
/// wider helper package; useful when only the duration itself matters.
String relativeOrderTime(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${t.day}/${t.month}/${t.year}';
}

/// Internal: re-export the canonical status strings so widget tests can
/// resolve the production values without importing the service file.
class OrderStatusLabels {
  OrderStatusLabels._();
  static const String paidOut = 'PAID OUT';
  static const String dispatched = 'DISPATCHED';
  static const String onWay = 'ON WAY';
  static const String delivered = 'DELIVERED';
  static const String cancelled = 'CANCELLED';
}

/// Convenience: build an [OrderRecord] for tests / previews.
OrderRecord debugOrder({
  String id = 'order-1',
  String status = 'PAID OUT',
  String street = '1 Lê Lợi',
  double amount = 0,
  DateTime? createdAt,
  String clientId = 'u1',
}) {
  return OrderRecord(
    id: id,
    clientId: clientId,
    addressId: 'a1',
    street: street,
    reference: 'District 1',
    latitude: 10.7717,
    longitude: 106.7009,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: status,
    products: const [],
    createdAt: createdAt ?? DateTime.now(),
  );
}
