import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/dashboard/dashboard_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import 'widgets/recent_orders.dart';
import 'widgets/revenue_chart.dart';

/// AdminDashboardScreen — the admin home (UC-07).
///
/// The screen is a scroll view with four blocks:
///
///   1. three stat tiles (today's revenue, new orders, new customers),
///   2. the seven-day revenue chart,
///   3. the recent-orders widget,
///   4. the quick-action shortcuts into the CRUD screens and the
///      delivery management.
class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardBloc>(
      create: (context) => DashboardBloc(
        ordersService: context.read<AdminOrdersService>(),
        usersService: context.read<AdminUsersService>(),
      )..add(const DashboardLoadRequested()),
      child: const _AdminDashboardView(),
    );
  }
}

class _AdminDashboardView extends StatelessWidget {
  const _AdminDashboardView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) => current is LogOutAuthState,
      listener: (context, state) {
        // Replace the stack so the back button cannot return to the admin
        // home of the session that just ended. The global auth listener in
        // `main.dart` does the same thing for every other role; this one
        // keeps the dashboard correct even when it is mounted on its own
        // (widget tests, previews).
        context.go('/login');
      },
      child: Scaffold(
        backgroundColor: ColorsFrave.pageBg,
        body: SafeArea(
          child: BlocBuilder<DashboardBloc, DashboardState>(
            builder: (context, state) {
              return RefreshIndicator(
                color: ColorsFrave.navOrange,
                onRefresh: () async {
                  context
                      .read<DashboardBloc>()
                      .add(const DashboardRefreshRequested());
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: <Widget>[
                    const _DashboardHeader(),
                    const SizedBox(height: 20),
                    if (state.error != null && state.recentOrders.isEmpty)
                      _DashboardError(message: context.failure(state.error!)),
                    if (state.isLoading && state.recentOrders.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: ColorsFrave.navOrange,
                          ),
                        ),
                      ),
                    if (state.error == null) ...<Widget>[
                      _StatsRow(state: state),
                      const SizedBox(height: 20),
                      _RevenueChartCard(state: state),
                      const SizedBox(height: 20),
                      _RecentOrdersCard(state: state),
                      const SizedBox(height: 20),
                      const _QuickActions(),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The header — greeting with the admin's name plus a sign-out button.
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthBloc, String>(
      (bloc) => bloc.state.user?.fullName ?? '',
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.adminDashboardTitle,
                style: FraveText.bold(26, color: ColorsFrave.ink),
              ),
              if (user.isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  context.l10n.adminGreeting(user),
                  style: FraveText.regular(14, color: ColorsFrave.greyText),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        const _AdminSignOutButton(),
      ],
    );
  }
}

/// The small session pill in the dashboard header.
///
/// While the admin is signed in it reads "Đăng xuất" and signs them out;
/// once signed out it reads "Đăng nhập" and takes them back to the login
/// form.
class _AdminSignOutButton extends StatelessWidget {
  const _AdminSignOutButton();

  @override
  Widget build(BuildContext context) {
    final isSignedIn = context.select<AuthBloc, bool>(
      (bloc) => bloc.state.user != null,
    );
    return Material(
      color: ColorsFrave.surfaceColor,
      borderRadius: BorderRadius.circular(100),
      child: InkWell(
        borderRadius: BorderRadius.circular(100),
        onTap: () {
          if (isSignedIn) {
            context.read<AuthBloc>().add(LogOutEvent());
            return;
          }
          context.go('/login');
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.logout_rounded,
                size: 16,
                color: ColorsFrave.navOrange,
              ),
              const SizedBox(width: 6),
              Text(
                isSignedIn
                    ? context.l10n.actionSignOut
                    : context.l10n.profileSignIn,
                style: FraveText.medium(13, color: ColorsFrave.navOrange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The three stat tiles.
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    final stats = state.stats;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatTile(
              label: context.l10n.adminStatRevenueToday,
              value: Money.format(stats.todayRevenue),
              icon: Icons.payments_outlined,
              color: ColorsFrave.navOrange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: context.l10n.adminStatNewOrders,
              value: '${stats.newOrders}',
              icon: Icons.receipt_long_outlined,
              color: ColorsFrave.secondaryColor,
              // Tapping the tile opens the orders the customers just
              // placed — the restaurant's "what came in?" view.
              onTap: () => context.push('/admin/orders/new'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              label: context.l10n.adminStatNewUsers,
              value: '${stats.newUsers}',
              icon: Icons.people_alt_outlined,
              color: ColorsFrave.tertiaryColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// One stat tile.
class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// When set, the tile becomes a button that opens the related screen.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: FraveText.bold(18, color: ColorsFrave.ink),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FraveText.light(12, color: ColorsFrave.greyText),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
        child: content,
      ),
    );
  }
}

/// The card that wraps the seven-day revenue chart.
class _RevenueChartCard extends StatelessWidget {
  const _RevenueChartCard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            context.l10n.adminRevenueChartTitle,
            style: FraveText.semiBold(18, color: ColorsFrave.ink),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.adminRevenueChartOrders,
            style: FraveText.light(13, color: ColorsFrave.greyText),
          ),
          const SizedBox(height: 14),
          RevenueChart(dailyStats: state.dailyStats),
          const SizedBox(height: 10),
          OrderCountChart(dailyStats: state.dailyStats, height: 90),
        ],
      ),
    );
  }
}

/// The card that wraps the recent-orders widget.
class _RecentOrdersCard extends StatelessWidget {
  const _RecentOrdersCard({required this.state});

  final DashboardState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: RecentOrders(
        orders: state.recentOrders,
        onViewAll: () => context.push('/admin/orders'),
        onTapOrder: (OrderRecord order) =>
            context.push('/admin/orders/${order.id}'),
      ),
    );
  }
}

/// The quick-action shortcuts.
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <_QuickAction>[
      _QuickAction(
        label: context.l10n.adminQuickCategories,
        icon: Icons.category_outlined,
        route: '/admin/categories',
      ),
      _QuickAction(
        label: context.l10n.adminQuickProducts,
        icon: Icons.restaurant_menu_outlined,
        route: '/admin/products',
      ),
      _QuickAction(
        label: context.l10n.adminQuickOrders,
        icon: Icons.receipt_long_outlined,
        route: '/admin/orders',
      ),
      _QuickAction(
        label: context.l10n.adminQuickDelivery,
        icon: Icons.delivery_dining_outlined,
        route: '/admin/delivery',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          context.l10n.adminQuickActionsTitle,
          style: FraveText.semiBold(18, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 3.4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: <Widget>[
            for (final action in actions)
              _QuickActionTile(
                action: action,
                onTap: () {
                  final router = GoRouter.of(context);
                  router.push(action.route);
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// The data of one quick action.
class _QuickAction {
  const _QuickAction({
    required this.label,
    required this.icon,
    required this.route,
  });

  final String label;
  final IconData icon;
  final String route;
}

/// One quick-action tile.
class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorsFrave.surfaceColor,
      borderRadius: BorderRadius.circular(RadiusFrave.card),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ColorsFrave.orangeSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(action.icon, size: 18, color: ColorsFrave.navOrange),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    action.label,
                    maxLines: 1,
                    style: FraveText.medium(14, color: ColorsFrave.ink),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The error state — shown when the feed failed and nothing is cached.
class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Column(
        children: <Widget>[
          const Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: ColorsFrave.navOrange,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: FraveText.regular(13, color: ColorsFrave.greyText),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              context
                  .read<DashboardBloc>()
                  .add(const DashboardLoadRequested());
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: ColorsFrave.navOrange,
              side: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100),
              ),
            ),
            child: Text(
              context.l10n.ordersTryAgain,
              style: FraveText.medium(14, color: ColorsFrave.navOrange),
            ),
          ),
        ],
      ),
    );
  }
}
