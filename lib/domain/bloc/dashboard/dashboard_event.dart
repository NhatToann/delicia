part of 'dashboard_bloc.dart';

@immutable
abstract class DashboardEvent {
  const DashboardEvent();
}

/// Opens (or re-opens) the live order feed the dashboard is built on.
class DashboardLoadRequested extends DashboardEvent {
  const DashboardLoadRequested();
}

/// Pull-to-refresh — re-opens the feed.
class DashboardRefreshRequested extends DashboardEvent {
  const DashboardRefreshRequested();
}

/// Internal event — a new batch of orders arrived.
class _DashboardOrdersUpdated extends DashboardEvent {
  const _DashboardOrdersUpdated(this.orders);
  final List<OrderRecord> orders;
}

/// Internal event — the order feed failed.
class _DashboardOrdersFailed extends DashboardEvent {
  const _DashboardOrdersFailed(this.error);
  final Object error;
}

/// Internal event — a new batch of customer accounts arrived.
class _DashboardCustomersUpdated extends DashboardEvent {
  const _DashboardCustomersUpdated(this.customers);
  final List<CustomerAccount> customers;
}
