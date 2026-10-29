import 'order_record.dart';

/// Which subset of [OrderRecord]s the My Orders screen is currently
/// showing. Each filter maps to a set of statuses that the order can be
/// in. Centralised here so the UI never has to know about raw status
/// strings (e.g. `"ON WAY"`); it just asks the filter "does this order
/// belong to me?", which keeps the mapping testable on its own.
///
/// Replaces the older single-order design (which only had `lastOrder`)
/// with the per-client list needed by Figma node `147:2153` (My Orders).
enum OrderFilter {
  /// Orders that are in flight: just paid out, dispatched, or on the way
  /// to the customer. These are the only orders a courier is currently
  /// working on and the only ones for which tracking makes sense.
  active,

  /// Orders that reached the customer and have been delivered.
  completed,

  /// Orders that the customer (or restaurant) voided before delivery.
  cancelled;

  /// Stable machine-readable identifier.
  ///
  /// This is *not* user-facing copy — the screen renders
  /// `context.l10n.ordersFilter*` instead. The id is used for widget keys
  /// and analytics events, where a stable, locale-independent value is
  /// required.
  String get id => name;

  /// Set of [OrderRecord.status] values that belong in this bucket.
  ///
  /// IMPORTANT: keep this in sync with the strings produced by the
  /// checkout / admin flows. [OrderRecord.statusPaidOut] etc. are the
  /// canonical source — if you add a new status, update here too.
  Set<String> get statuses {
    switch (this) {
      case OrderFilter.active:
        return const <String>{
          OrderRecord.statusPaidOut,
          OrderRecord.statusDispatched,
          OrderRecord.statusOnWay,
        };
      case OrderFilter.completed:
        return const <String>{OrderRecord.statusDelivered};
      case OrderFilter.cancelled:
        return const <String>{OrderRecord.statusCancelled};
    }
  }

  /// Returns true when [order]'s status belongs to this filter.
  bool accepts(OrderRecord order) => statuses.contains(order.status);
}
