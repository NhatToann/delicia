/// The numbers shown at the top of the admin dashboard (UC-07).
///
/// Every figure is derived from the raw order / user lists — the
/// Realtime Database cannot aggregate, so the bloc computes the totals
/// once and hands them to the UI.
class DashboardStats {
  /// Revenue booked today, in USD.
  final double todayRevenue;

  /// Number of orders created today.
  final int newOrders;

  /// Number of new customers registered today.
  final int newUsers;

  /// Total number of orders, regardless of date.
  final int totalOrders;

  /// Total number of registered customers.
  final int totalUsers;

  const DashboardStats({
    this.todayRevenue = 0,
    this.newOrders = 0,
    this.newUsers = 0,
    this.totalOrders = 0,
    this.totalUsers = 0,
  });

  /// An empty snapshot — used as the initial state.
  static const DashboardStats empty = DashboardStats();

  DashboardStats copyWith({
    double? todayRevenue,
    int? newOrders,
    int? newUsers,
    int? totalOrders,
    int? totalUsers,
  }) =>
      DashboardStats(
        todayRevenue: todayRevenue ?? this.todayRevenue,
        newOrders: newOrders ?? this.newOrders,
        newUsers: newUsers ?? this.newUsers,
        totalOrders: totalOrders ?? this.totalOrders,
        totalUsers: totalUsers ?? this.totalUsers,
      );

  @override
  bool operator ==(Object other) =>
      other is DashboardStats &&
      other.todayRevenue == todayRevenue &&
      other.newOrders == newOrders &&
      other.newUsers == newUsers &&
      other.totalOrders == totalOrders &&
      other.totalUsers == totalUsers;

  @override
  int get hashCode =>
      Object.hash(todayRevenue, newOrders, newUsers, totalOrders, totalUsers);
}
