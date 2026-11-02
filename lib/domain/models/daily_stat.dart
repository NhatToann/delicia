/// One day of the admin revenue chart (UC-07).
///
/// The Realtime Database has no aggregation, so the seven-day series is
/// derived client-side from the raw order list. [revenue] is kept in the
/// same unit as `OrderRecord.amount` (USD) — the presentation layer
/// converts it to VND through `Money.format`.
class DailyStat {
  /// The day this bucket covers, normalised to midnight.
  final DateTime date;

  /// Total revenue of the day, in USD.
  final double revenue;

  /// Number of orders placed on that day.
  final int orders;

  const DailyStat({
    required this.date,
    required this.revenue,
    required this.orders,
  });

  /// Stable identifier — the day in `yyyy-MM-dd` form.
  ///
  /// Useful as a widget key and as a lookup key when merging two series.
  String get id => '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  bool operator ==(Object other) =>
      other is DailyStat &&
      other.date == date &&
      other.revenue == revenue &&
      other.orders == orders;

  @override
  int get hashCode => Object.hash(date, revenue, orders);
}
