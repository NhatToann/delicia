import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../../domain/services/client_orders_service.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';

/// OrderStatusTimeline — visual representation of an order's delivery
/// progress (UC-05).  Rendered as a vertical list of steps with an
/// active / done indicator so the user can see how far the delivery has
/// progressed at a glance.
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
            label: steps[i],
            isDone: !isCancelled && i < currentIndex,
            isActive: !isCancelled && i == currentIndex,
            isLast: i == steps.length - 1,
            key: ValueKey('timeline-${steps[i]}'),
          ),
        if (isCancelled)
          _StepRow(
            label: 'CANCELLED',
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

class _StepRow extends StatelessWidget {
  final String label;
  final bool isDone;
  final bool isActive;
  final bool isLast;
  final bool cancelled;

  const _StepRow({
    super.key,
    required this.label,
    required this.isDone,
    required this.isActive,
    required this.isLast,
    this.cancelled = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = cancelled
        ? ColorsFrave.errorColor
        : ColorsFrave.primaryColor;
    final dot = isActive
        ? accent
        : isDone
        ? accent
        : ColorsFrave.backgroundColor;
    final border = isDone || isActive ? accent : ColorsFrave.backgroundColor;
    final textColor = isDone || isActive || cancelled
        ? ColorsFrave.darkText
        : ColorsFrave.greyText;
    final fontWeight = isActive || cancelled
        ? FontWeight.bold
        : FontWeight.w500;

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
                      ? const Icon(Icons.check, size: 10, color: Colors.white)
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDone
                          ? ColorsFrave.primaryColor
                          : ColorsFrave.backgroundColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(top: 0, bottom: isLast ? 0 : 12),
            child: TextCustom(label, color: textColor, fontWeight: fontWeight),
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

/// Compact summary used by the order-list cards.  Reuses the canonical
/// status strings so widget tests can assert against the same shape the
/// production code uses.
class OrderStatusBadge extends StatelessWidget {
  final String status;
  const OrderStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toUpperCase();
    Color bg;
    Color fg;
    switch (normalized) {
      case 'PAID OUT':
        bg = ColorsFrave.primaryColor;
        fg = Colors.white;
        break;
      case 'DISPATCHED':
      case 'ON WAY':
        bg = ColorsFrave.secondaryColor;
        fg = Colors.white;
        break;
      case 'DELIVERED':
        bg = ColorsFrave.backgroundColor;
        fg = ColorsFrave.darkText;
        break;
      case 'CANCELLED':
        bg = ColorsFrave.errorColor;
        fg = Colors.white;
        break;
      default:
        bg = ColorsFrave.backgroundColor;
        fg = ColorsFrave.darkText;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextCustom(
        status.isEmpty ? 'UNKNOWN' : status,
        color: fg,
        fontSize: 12,
        fontWeight: FontWeight.w600,
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
