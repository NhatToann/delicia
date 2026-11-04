part of 'dashboard_bloc.dart';

@immutable
class DashboardState {
  /// True while the first batch of orders is loading.
  final bool isLoading;

  /// The failure of the last load, if any.
  final AppFailure? error;

  /// Today's revenue, order count and the running totals.
  final DashboardStats stats;

  /// The seven-day revenue / order series, oldest day first.
  final List<DailyStat> dailyStats;

  /// The most recent orders, newest first.
  final List<OrderRecord> recentOrders;

  /// The number of orders the platform currently holds.
  final int totalOrders;

  const DashboardState({
    this.isLoading = false,
    this.error,
    this.stats = DashboardStats.empty,
    this.dailyStats = const <DailyStat>[],
    this.recentOrders = const <OrderRecord>[],
    this.totalOrders = 0,
  });

  DashboardState copyWith({
    bool? isLoading,
    AppFailure? error,
    bool clearError = false,
    DashboardStats? stats,
    List<DailyStat>? dailyStats,
    List<OrderRecord>? recentOrders,
    int? totalOrders,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      stats: stats ?? this.stats,
      dailyStats: dailyStats ?? this.dailyStats,
      recentOrders: recentOrders ?? this.recentOrders,
      totalOrders: totalOrders ?? this.totalOrders,
    );
  }
}
