import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/delivery/delivery_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/order_record.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';
import 'widgets/available_orders_tab.dart';
import 'widgets/order_card_delivery.dart';

class DeliveryHomeScreen extends StatefulWidget {
  const DeliveryHomeScreen({super.key});

  @override
  State<DeliveryHomeScreen> createState() => _DeliveryHomeScreenState();
}

class _DeliveryHomeScreenState extends State<DeliveryHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _driverId = '';
  String _driverName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    final authState = context.read<AuthBloc>().state;
    _driverId = authState.user?.uid ?? 'driver_demo';
    _driverName = authState.user?.fullName ?? 'Delivery Partner';

    final deliveryBloc = context.read<DeliveryBloc>();
    deliveryBloc.add(LoadDeliveryHomeEvent(_driverId));
    deliveryBloc.add(WatchDeliveryHomeEvent(_driverId));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _confirmReject(BuildContext context, OrderRecord order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TextCustom('Reject Order', fontWeight: FontWeight.bold),
        content: TextCustom(
          'Are you sure you want to decline Order #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('Cancel', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<DeliveryBloc>().add(
                    RejectOrderEvent(orderId: order.id, deliveryId: _driverId),
                  );
            },
            child: const TextCustom('Reject', color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _navigateToMap(OrderRecord order) {
    context.read<OrdersBloc>().add(OnSetCurrentOrderEvent(order));
    context.push('/delivery/map/${order.id}');
  }

  void _navigateToDetails(OrderRecord order) {
    context.read<OrdersBloc>().add(OnSetCurrentOrderEvent(order));
    context.push('/delivery/details/${order.id}', extra: order);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: ColorsFrave.secondaryColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.two_wheeler_rounded,
                color: ColorsFrave.secondaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextCustom(
                  _driverName,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                const Row(
                  children: [
                    CircleAvatar(
                      radius: 4,
                      backgroundColor: ColorsFrave.successColor,
                    ),
                    SizedBox(width: 4),
                    TextCustom(
                      'Online & Ready',
                      color: ColorsFrave.successColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz, color: ColorsFrave.primaryColor),
            tooltip: 'Switch Role',
            onPressed: () => context.go('/select-role'),
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: ColorsFrave.greyText),
            tooltip: 'Log Out',
            onPressed: () {
              context.read<AuthBloc>().add(LogOutEvent());
              context.go('/login');
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: ColorsFrave.primaryColor,
          unselectedLabelColor: ColorsFrave.greyText,
          indicatorColor: ColorsFrave.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'My Deliveries'),
            Tab(text: 'Available Orders'),
          ],
        ),
      ),
      body: BlocConsumer<DeliveryBloc, DeliveryState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TextCustom(state.error!, color: Colors.white),
                backgroundColor: ColorsFrave.errorColor,
              ),
            );
          } else if (state.isSuccess && state.successMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: TextCustom(state.successMessage!, color: Colors.white),
                backgroundColor: ColorsFrave.successColor,
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // In-app Notification Banner for New Orders
              if (state.newOrderNotification != null) ...[
                _NewOrderNotificationBanner(
                  order: state.newOrderNotification!,
                  onDismiss: () {
                    context.read<DeliveryBloc>().add(const DismissNotificationEvent());
                  },
                  onView: () {
                    final order = state.newOrderNotification!;
                    context.read<DeliveryBloc>().add(const DismissNotificationEvent());
                    _navigateToDetails(order);
                  },
                ),
              ],

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Tab 1: My Deliveries (Assigned)
                    _MyDeliveriesTab(
                      orders: state.assignedOrders,
                      isLoading: state.isLoading,
                      onRefresh: () async {
                        context
                            .read<DeliveryBloc>()
                            .add(LoadDeliveryHomeEvent(_driverId));
                      },
                      onTap: _navigateToDetails,
                      onReject: (order) => _confirmReject(context, order),
                      onNavigateMap: _navigateToMap,
                    ),

                    // Tab 2: Available Orders
                    AvailableOrdersTab(
                      orders: state.availableOrders,
                      isLoading: state.isLoading,
                      onRefresh: () async {
                        context
                            .read<DeliveryBloc>()
                            .add(LoadDeliveryHomeEvent(_driverId));
                      },
                      onTap: _navigateToDetails,
                      onAccept: (order) {
                        context.read<DeliveryBloc>().add(
                              AcceptOrderEvent(
                                orderId: order.id,
                                deliveryId: _driverId,
                                deliveryName: _driverName,
                              ),
                            );
                        _tabController.animateTo(0);
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MyDeliveriesTab extends StatelessWidget {
  final List<OrderRecord> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderRecord> onTap;
  final ValueChanged<OrderRecord> onReject;
  final ValueChanged<OrderRecord> onNavigateMap;

  const _MyDeliveriesTab({
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onTap,
    required this.onReject,
    required this.onNavigateMap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
      );
    }

    if (orders.isEmpty) {
      return RefreshIndicator(
        color: ColorsFrave.primaryColor,
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Container(
            height: MediaQuery.of(context).size.height * 0.6,
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.moped_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const TextCustom(
                  'No assigned orders yet',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorsFrave.darkText,
                ),
                const SizedBox(height: 4),
                const TextCustom(
                  'Check "Available Orders" tab to accept new deliveries!',
                  fontSize: 13,
                  color: ColorsFrave.greyText,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: ColorsFrave.primaryColor,
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCardDelivery(
            order: order,
            isAvailableTab: false,
            onTap: () => onTap(order),
            onReject: () => onReject(order),
            onNavigateMap: () => onNavigateMap(order),
          );
        },
      ),
    );
  }
}

class _NewOrderNotificationBanner extends StatelessWidget {
  final OrderRecord order;
  final VoidCallback onDismiss;
  final VoidCallback onView;

  const _NewOrderNotificationBanner({
    required this.order,
    required this.onDismiss,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFEEBA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.orange,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_active, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const TextCustom(
                  'New Order Assigned!',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF856404),
                ),
                TextCustom(
                  'Order #$shortId • \$${order.amount.toStringAsFixed(2)}',
                  fontSize: 12,
                  color: const Color(0xFF856404),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onView,
            child: const TextCustom(
              'View',
              fontWeight: FontWeight.bold,
              color: ColorsFrave.primaryColor,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
