import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/daily_stat.dart';
import '../../models/dashboard_stats.dart';
import '../../models/customer_account.dart';
import '../../models/order_record.dart';
import '../../services/admin_orders_service.dart';
import '../../services/app_failure.dart';
part 'dashboard_event.dart';
part 'dashboard_state.dart';

/// DashboardBloc — the numbers behind the admin home screen (UC-07).
///
/// The Realtime Database cannot aggregate, so the bloc keeps the raw
/// order list in memory and derives:
///
///   * today's revenue and order count,
///   * the number of new customers today,
///   * the seven-day revenue / order series,
///   * the five most recent orders.
///
/// The order list arrives on a Firebase stream. As with every other bloc
/// in this project, the listener never writes to the state directly —
/// by the time the event arrives the handler that opened the
/// subscription has already returned and its [Emitter] is closed. The
/// listener therefore feeds an internal event instead.
class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc({
    required AdminOrdersService ordersService,
    AdminUsersService? usersService,
    DateTime Function()? clock,
  })  : _ordersService = ordersService,
        _usersService = usersService,
        _clock = clock ?? DateTime.now,
        super(const DashboardState()) {
    on<DashboardLoadRequested>(_onLoadRequested);
    on<DashboardRefreshRequested>(_onRefreshRequested);
    on<_DashboardOrdersUpdated>(_onOrdersUpdated);
    on<_DashboardOrdersFailed>(_onOrdersFailed);
    on<_DashboardCustomersUpdated>(_onCustomersUpdated);
  }

  final AdminOrdersService _ordersService;

  /// Optional — when it is missing the "new customers" tile stays at 0.
  final AdminUsersService? _usersService;

  /// The clock used to decide what "today" means.
  ///
  /// Injected so the tests can pin "today" instead of depending on the
  /// machine's wall clock (same trick as `ClientHomeScreen.clock`).
  final DateTime Function() _clock;

  StreamSubscription<List<OrderRecord>>? _ordersSub;
  StreamSubscription<List<CustomerAccount>>? _customersSub;

  /// How many days the revenue chart covers.
  static const int chartDays = 7;

  /// How many orders the "recent orders" widget shows.
  static const int recentOrdersLimit = 5;

  Future<void> _onLoadRequested(
    DashboardLoadRequested event,
    Emitter<DashboardState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    await _ordersSub?.cancel();
    _ordersSub = null;

    _ordersSub = _ordersService.watchAllOrders().listen(
      (orders) {
        if (isClosed) return;
        add(_DashboardOrdersUpdated(orders));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_DashboardOrdersFailed(e));
      },
    );

    final usersService = _usersService;
    if (usersService == null) return;

    await _customersSub?.cancel();
    _customersSub = usersService.watchCustomers().listen(
      (customers) {
        if (isClosed) return;
        add(_DashboardCustomersUpdated(customers));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_DashboardOrdersFailed(e));
      },
    );
  }

  Future<void> _onRefreshRequested(
    DashboardRefreshRequested event,
    Emitter<DashboardState> emit,
  ) async {
    // A refresh simply re-opens the stream — the first event that
    // arrives carries the fresh snapshot.
    await _onLoadRequested(const DashboardLoadRequested(), emit);
  }

  void _onOrdersUpdated(
    _DashboardOrdersUpdated event,
    Emitter<DashboardState> emit,
  ) {
    final now = _clock();
    emit(
      state.copyWith(
        isLoading: false,
        clearError: true,
        stats: _statsOf(event.orders, now),
        dailyStats: _dailyStatsOf(event.orders, now),
        recentOrders: event.orders.take(recentOrdersLimit).toList(),
        totalOrders: event.orders.length,
      ),
    );
  }

  void _onOrdersFailed(
    _DashboardOrdersFailed event,
    Emitter<DashboardState> emit,
  ) {
    emit(state.copyWith(isLoading: false, error: asFailure(event.error)));
  }

  /// A new batch of customer accounts arrived — recount the "new users".
  void _onCustomersUpdated(
    _DashboardCustomersUpdated event,
    Emitter<DashboardState> emit,
  ) {
    final now = _clock();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    var newUsers = 0;
    for (final customer in event.customers) {
      if (customer.createdAt.isBefore(startOfToday)) continue;
      if (!customer.createdAt.isBefore(endOfToday)) continue;
      newUsers++;
    }

    emit(
      state.copyWith(
        stats: state.stats.copyWith(
          newUsers: newUsers,
          totalUsers: event.customers.length,
        ),
      ),
    );
  }

  /// Computes today's figures from the raw order list.
  DashboardStats _statsOf(List<OrderRecord> orders, DateTime now) {
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = startOfToday.add(const Duration(days: 1));

    var todayRevenue = 0.0;
    var newOrders = 0;
    for (final order in orders) {
      if (order.createdAt.isBefore(startOfToday)) continue;
      if (!order.createdAt.isBefore(endOfToday)) continue;
      todayRevenue += order.amount;
      newOrders++;
    }

    return DashboardStats(
      todayRevenue: todayRevenue,
      newOrders: newOrders,
      newUsers: state.stats.newUsers,
      totalOrders: orders.length,
      totalUsers: state.stats.totalUsers,
    );
  }

  /// Builds the seven-day series, oldest day first.
  ///
  /// Every day of the window is present — a day without orders is a zero
  /// bar, not a missing one, so the chart never jumps around.
  List<DailyStat> _dailyStatsOf(List<OrderRecord> orders, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: chartDays - 1));

    final buckets = <DateTime, List<OrderRecord>>{
      for (var i = 0; i < chartDays; i++)
        start.add(Duration(days: i)): <OrderRecord>[],
    };

    for (final order in orders) {
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      );
      buckets[day]?.add(order);
    }

    return buckets.entries.map((entry) {
      final revenue = entry.value.fold<double>(
        0,
        (sum, order) => sum + order.amount,
      );
      return DailyStat(
        date: entry.key,
        revenue: revenue,
        orders: entry.value.length,
      );
    }).toList(growable: false);
  }

  @override
  Future<void> close() async {
    await _ordersSub?.cancel();
    await _customersSub?.cancel();
    _ordersSub = null;
    _customersSub = null;
    return super.close();
  }
}
