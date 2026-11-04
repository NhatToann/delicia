import '../models/order_record.dart';

/// Which subset of orders the **admin** orders screen is showing (UC-09).
///
/// The customer-facing [OrderFilter] groups orders by lifecycle stage
/// (in flight / done / voided). The admin needs a finer split, because
/// the restaurant works through a queue: an order waits, then it is being
/// prepared, then a courier carries it, then it lands.
///
/// The enum only carries stable identifiers — the Vietnamese labels live
/// in the ARB file and are mapped in the presentation layer.
enum AdminOrderFilter {
  /// Every order, whatever its status.
  all,

  /// Paid, but the restaurant has not started preparing it yet.
  pending,

  /// The kitchen is preparing the order.
  preparing,

  /// A courier has been assigned and is carrying the order.
  delivering,

  /// The order reached the customer.
  completed,

  /// The order was voided.
  cancelled;

  /// Stable machine-readable identifier (locale independent).
  String get id => name;

  /// The order statuses that belong to this filter.
  ///
  /// [AdminOrderFilter.all] accepts everything, so its set is `null` —
  /// an empty set would mean "nothing matches".
  Set<String>? get statuses {
    switch (this) {
      case AdminOrderFilter.all:
        return null;
      case AdminOrderFilter.pending:
        return const <String>{OrderRecord.statusPaidOut};
      case AdminOrderFilter.preparing:
        return const <String>{OrderRecord.statusPreparing};
      case AdminOrderFilter.delivering:
        return const <String>{
          OrderRecord.statusDispatched,
          OrderRecord.statusOnWay,
        };
      case AdminOrderFilter.completed:
        return const <String>{OrderRecord.statusDelivered};
      case AdminOrderFilter.cancelled:
        return const <String>{OrderRecord.statusCancelled};
    }
  }

  /// Whether [order] belongs to this filter.
  bool accepts(OrderRecord order) {
    final set = statuses;
    if (set == null) return true;
    return set.contains(order.status);
  }
}
