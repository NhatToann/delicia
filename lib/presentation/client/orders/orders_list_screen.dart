import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/client_orders/client_orders_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../components/btn_frave.dart';
import '../../components/shimmer_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';
import 'widgets/order_status_timeline.dart';

/// OrdersListScreen — the client's order history (UC-05).
///
/// Shows two tabs:
///   * **Active** — orders that aren't yet delivered / cancelled.
///   * **History** — delivered + cancelled orders.
///
/// Tapping any card opens the order-detail screen, which subscribes to
/// the order's realtime updates.
class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _loadedUid;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // No data fetch here — the build() method reacts to AuthBloc state
    // changes and kicks off the load once the user is available.
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          // After checkout the app navigates to this screen with `go()`,
          // which replaces the whole stack — so there is nothing to pop
          // and the back button would silently do nothing.  Fall back to
          // the client home screen in that case.
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/client/home');
            }
          },
        ),
        title: const TextCustom('My Orders', fontWeight: FontWeight.bold),
        centerTitle: true,
        actions: [
          BlocBuilder<ClientOrdersBloc, ClientOrdersState>(
            buildWhen: (a, b) => a.realtimeActive != b.realtimeActive,
            builder: (_, state) {
              final uid = context.read<AuthBloc>().state.user?.uid ?? '';
              return IconButton(
                tooltip: state.realtimeActive ? 'Live updates on' : 'Refresh',
                icon: Icon(
                  state.realtimeActive ? Icons.wifi_tethering : Icons.refresh,
                  color: ColorsFrave.primaryColor,
                ),
                onPressed: () {
                  if (uid.isEmpty) {
                    errorTextSnack(context, 'Sign in to refresh orders.');
                    return;
                  }
                  context.read<ClientOrdersBloc>().add(
                    OnRefreshClientOrdersEvent(clientId: uid),
                  );
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ColorsFrave.primaryColor,
          unselectedLabelColor: ColorsFrave.greyText,
          indicatorColor: ColorsFrave.primaryColor,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: BlocBuilder<AuthBloc, AuthState>(
        buildWhen: (a, b) => a.user?.uid != b.user?.uid,
        builder: (authCtx, authState) {
          final uid = authState.user?.uid ?? '';
          if (uid.isNotEmpty && _loadedUid != uid) {
            _loadedUid = uid;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<ClientOrdersBloc>().add(
                OnLoadClientOrdersEvent(clientId: uid),
              );
              context.read<ClientOrdersBloc>().add(
                OnSubscribeClientOrdersEvent(clientId: uid),
              );
            });
          } else if (uid.isEmpty) {
            _loadedUid = null;
          }
          return BlocConsumer<ClientOrdersBloc, ClientOrdersState>(
            listenWhen: (a, b) =>
                a.error != b.error || a.lastUpdatedOrder != b.lastUpdatedOrder,
            listener: (ctx, state) {
              if (state.error != null) {
                errorTextSnack(context, state.error!);
              } else if (state.lastUpdatedOrder != null) {
                modalSuccessOrInfo(
                  context,
                  'Cancellation confirmed for '
                  '#${state.lastUpdatedOrder!.id.substring(0, state.lastUpdatedOrder!.id.length.clamp(0, 8))}',
                );
              }
            },
            builder: (ctx, state) {
              if (state.isLoading && state.orders.isEmpty) {
                return const _LoadingShell();
              }
              return TabBarView(
                controller: _tabController,
                children: [
                  _OrderList(orders: state.activeOrders, cancellable: true),
                  _OrderList(orders: state.historyOrders, cancellable: false),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// Compact inline confirmation helper used by the listener — sticks to
/// a non-blocking snack so the user can keep scrolling.
void modalSuccessOrInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: ColorsFrave.successColor,
        duration: const Duration(seconds: 2),
      ),
    );
}

class _OrderList extends StatelessWidget {
  final List<OrderRecord> orders;
  final bool cancellable;

  const _OrderList({required this.orders, required this.cancellable});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(isHistory: !cancellable);
    }
    return RefreshIndicator(
      color: ColorsFrave.primaryColor,
      onRefresh: () async {
        final uid = context.read<AuthBloc>().state.user?.uid ?? '';
        if (uid.isEmpty) return;
        context.read<ClientOrdersBloc>().add(
          OnRefreshClientOrdersEvent(clientId: uid),
        );
        await Future<void>.delayed(const Duration(milliseconds: 600));
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) =>
            _OrderCard(order: orders[i], cancellable: cancellable),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderRecord order;
  final bool cancellable;

  const _OrderCard({required this.order, required this.cancellable});

  @override
  Widget build(BuildContext context) {
    final itemCount = order.products.fold<int>(0, (s, p) => s + p.quantity);
    final canCancelNow = cancellable && isOrderCancellable(order.status);
    final cancelling = context.select<ClientOrdersBloc, bool>(
      (b) => b.state.cancellingOrderId == order.id,
    );
    final clientId = context.read<AuthBloc>().state.user?.uid ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () =>
          context.push('/client/orders/detail/${order.id}', extra: order),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextCustom(
                    'Order #${order.id.substring(0, order.id.length.clamp(0, 8))}',
                    fontWeight: FontWeight.bold,
                  ),
                ),
                OrderStatusBadge(status: order.status),
              ],
            ),
            const SizedBox(height: 6),
            TextCustom(
              relativeOrderTime(order.createdAt),
              color: ColorsFrave.greyText,
              fontSize: 13,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextCustom(
                  '$itemCount item${itemCount == 1 ? '' : 's'}',
                  color: ColorsFrave.greyText,
                  fontSize: 13,
                ),
                TextCustom(
                  '\$${order.amount.toStringAsFixed(2)}',
                  fontWeight: FontWeight.bold,
                  color: ColorsFrave.primaryColor,
                ),
              ],
            ),
            if (canCancelNow) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 38,
                    child: cancelling
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: ColorsFrave.primaryColor,
                              ),
                            ),
                          )
                        : TextButton.icon(
                            onPressed: cancelling
                                ? null
                                : () => _confirmCancel(context, clientId),
                            icon: const Icon(
                              Icons.cancel_outlined,
                              size: 18,
                              color: ColorsFrave.errorColor,
                            ),
                            label: const TextCustom(
                              'Cancel',
                              color: ColorsFrave.errorColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context, String clientId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const TextCustom(
          'Cancel this order?',
          fontWeight: FontWeight.bold,
        ),
        content: const TextCustom(
          'Once cancelled, the order can no longer be reversed.',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TextCustom('Keep order', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel order'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<ClientOrdersBloc>().add(
        OnCancelOrderEvent(clientId: clientId, orderId: order.id),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  final bool isHistory;
  const _EmptyState({required this.isHistory});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long_outlined,
              size: 96,
              color: ColorsFrave.greyText,
            ),
            const SizedBox(height: 12),
            TextCustom(
              isHistory ? 'No previous orders yet' : 'No active orders',
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 6),
            TextCustom(
              isHistory
                  ? 'Once an order is delivered or cancelled it will show up here.'
                  : 'Place an order and it will show up here in real time.',
              color: ColorsFrave.greyText,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!isHistory)
              BtnFrave(
                text: 'Start Shopping',
                onPressed: () => context.go('/client/home'),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return ShimmerFrave(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
