import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../data/env/environment.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/bloc/delivery/delivery_bloc.dart';
import '../../../domain/bloc/orders/orders_bloc.dart';
import '../../../domain/models/delivery_status.dart';
import '../../../domain/models/order_record.dart';
import '../../../domain/utils/driver_earnings.dart';
import '../../components/text_custom.dart';
import '../../helpers/money.dart';
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
    _tabController = TabController(length: 3, vsync: this);

    final authState = context.read<AuthBloc>().state;
    _driverId = authState.user?.uid ?? 'driver_demo';
    _driverName = authState.user?.fullName ?? 'Tài xế Delicia';

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
        title: const TextCustom('Từ chối đơn hàng', fontWeight: FontWeight.bold),
        content: TextCustom(
          'Bạn có chắc chắn muốn từ chối Đơn hàng #${order.id.length > 8 ? order.id.substring(0, 8) : order.id}?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('Hủy', color: ColorsFrave.greyText),
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
            child: const TextCustom('Từ chối', color: Colors.white),
          ),
        ],
      ),
    );
  }

  void _confirmDelivered(BuildContext context, OrderRecord order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const TextCustom('Xác nhận đã giao', fontWeight: FontWeight.bold),
        content: TextCustom(
          'Bạn có chắc chắn đã giao đơn hàng #${order.id.length > 8 ? order.id.substring(0, 8) : order.id} đến tay khách hàng?',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const TextCustom('Hủy', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.successColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              final currentStatus = DeliveryStatus.fromString(order.status);
              context.read<DeliveryBloc>().add(
                    UpdateOrderStatusEvent(
                      orderId: order.id,
                      currentStatus: currentStatus,
                      targetStatus: DeliveryStatus.delivered,
                    ),
                  );
              context.read<OrdersBloc>().add(
                    const OnUpdateLastOrderStatusEvent(OrderRecord.statusDelivered),
                  );
            },
            child: const TextCustom('Xác nhận', color: Colors.white),
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
                      'Online & Sẵn sàng',
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
            icon: const Icon(Icons.logout, color: ColorsFrave.greyText),
            tooltip: 'Đăng xuất',
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
            Tab(text: 'Đơn đang giao'),
            Tab(text: 'Đơn chờ nhận'),
            Tab(text: 'Thu nhập'),
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
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              // In-app Notification Banner for New Orders
              if (state.newOrderNotification != null && !state.hasActiveDelivery) ...[
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
                    // Tab 1: Đơn đang giao (Assigned)
                    _MyDeliveriesTab(
                      orders: state.assignedOrders,
                      isLoading: state.isLoading,
                      onRefresh: () async {
                        context
                            .read<DeliveryBloc>()
                            .add(LoadDeliveryHomeEvent(_driverId));
                      },
                      onTap: _navigateToDetails,
                      onNavigateMap: _navigateToMap,
                      onDelivered: (order) => _confirmDelivered(context, order),
                    ),

                    // Tab 2: Đơn chờ nhận (Available Orders)
                    AvailableOrdersTab(
                      orders: state.availableOrders,
                      isLoading: state.isLoading,
                      hasActiveDelivery: state.hasActiveDelivery,
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
                      onReject: (order) => _confirmReject(context, order),
                    ),

                    // Tab 3: Thu nhập (Earnings)
                    _EarningsTab(
                      orders: state.assignedOrders,
                      isLoading: state.isLoading,
                      onRefresh: () async {
                        context
                            .read<DeliveryBloc>()
                            .add(LoadDeliveryHomeEvent(_driverId));
                      },
                      onTap: _navigateToDetails,
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
  final ValueChanged<OrderRecord> onNavigateMap;
  final ValueChanged<OrderRecord> onDelivered;

  const _MyDeliveriesTab({
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onTap,
    required this.onNavigateMap,
    required this.onDelivered,
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
            padding: const EdgeInsets.symmetric(horizontal: 24),
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
                  'Chưa có đơn hàng nào',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorsFrave.darkText,
                ),
                const SizedBox(height: 4),
                const TextCustom(
                  'Chuyển sang tab "Đơn chờ nhận" để nhận chuyến giao mới!',
                  fontSize: 13,
                  color: ColorsFrave.greyText,
                  textAlign: TextAlign.center,
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
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCardDelivery(
            order: order,
            isAvailableTab: false,
            onTap: () => onTap(order),
            onNavigateMap: () => onNavigateMap(order),
            onDelivered: () => onDelivered(order),
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
                  'Có đơn hàng mới!',
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF856404),
                ),
                TextCustom(
                  'Đơn #$shortId • ${Money.format(order.amount)}',
                  fontSize: 12,
                  color: const Color(0xFF856404),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onView,
            child: const TextCustom(
              'Xem',
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

class _EarningsTab extends StatelessWidget {
  final List<OrderRecord> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderRecord> onTap;

  const _EarningsTab({
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && orders.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: ColorsFrave.primaryColor),
      );
    }

    final deliveredOrders = orders
        .where((o) => o.status == OrderRecord.statusDelivered)
        .toList();

    // 90% of dynamic distance-based shipping fee per delivered order
    double totalEarnings = 0.0;
    for (final order in deliveredOrders) {
      totalEarnings += DriverEarnings.earningsUsdForOrder(order);
    }

    return RefreshIndicator(
      color: ColorsFrave.primaryColor,
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero Earnings Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [ColorsFrave.navOrange, Color(0xFFFF7A45)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: ColorsFrave.navOrange.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const TextCustom(
                        'Tổng thu nhập tích lũy',
                        color: ColorsFrave.onOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextCustom(
                    Money.format(totalEarnings),
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        TextCustom(
                          'Đã hoàn thành ${deliveredOrders.length} đơn hàng',
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Policy / Calculation Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: ColorsFrave.primaryColor,
                      ),
                      SizedBox(width: 8),
                      TextCustom(
                        'Chính sách thu nhập & Phí ship',
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: ColorsFrave.darkText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildEarningsRow(
                    'Dưới 1 km',
                    'Miễn phí (0 ₫)',
                  ),
                  const SizedBox(height: 6),
                  _buildEarningsRow(
                    'Từ 1 - 3 km',
                    '5.000 ₫ / km',
                  ),
                  const SizedBox(height: 6),
                  _buildEarningsRow(
                    'Từ 3 - 8 km',
                    '8.000 ₫ / km',
                  ),
                  const SizedBox(height: 6),
                  _buildEarningsRow(
                    'Trên 8 km',
                    '10.000 ₫ / km',
                  ),
                  const Divider(height: 16),
                  _buildEarningsRow(
                    'Tỷ lệ tài xế nhận',
                    '90% (Dưới 1 km: 5.000 ₫)',
                    isHighlight: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Header for delivered history
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const TextCustom(
                  'Lịch sử đơn đã giao',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorsFrave.darkText,
                ),
                TextCustom(
                  '${deliveredOrders.length} đơn',
                  fontSize: 13,
                  color: ColorsFrave.greyText,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (deliveredOrders.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 52,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 10),
                    const TextCustom(
                      'Chưa có đơn hàng hoàn thành',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: ColorsFrave.darkText,
                    ),
                    const SizedBox(height: 4),
                    const TextCustom(
                      'Sau khi giao hàng thành công, 90% phí ship sẽ được cộng vào thu nhập tại đây.',
                      fontSize: 12,
                      color: ColorsFrave.greyText,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: deliveredOrders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final order = deliveredOrders[index];
                  final shortId = order.id.length > 8
                      ? order.id.substring(0, 8)
                      : order.id;

                  final distKm = DriverEarnings.calculateDistanceKm(order);
                  final feeUsd = CartPricing.deliveryFeeUsd(distKm);
                  final orderPayout = DriverEarnings.earningsUsdForOrder(order);

                  return InkWell(
                    onTap: () => onTap(order),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextCustom(
                                'Đơn hàng #$shortId',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: ColorsFrave.darkText,
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: ColorsFrave.successColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: TextCustom(
                                  '+ ${Money.format(orderPayout)}',
                                  color: ColorsFrave.successColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: ColorsFrave.greyText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextCustom(
                                  order.street.isNotEmpty
                                      ? order.street
                                      : 'Địa chỉ giao hàng',
                                  fontSize: 12,
                                  color: ColorsFrave.greyText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              TextCustom(
                                distKm < 1.0
                                    ? '< 1 km (Nhận 5.000 ₫)'
                                    : '90% phí ship (${distKm.toStringAsFixed(1)} km - ${Money.format(feeUsd)})',
                                fontSize: 11,
                                color: Colors.grey.shade500,
                              ),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    size: 13,
                                    color: ColorsFrave.successColor,
                                  ),
                                  SizedBox(width: 4),
                                  TextCustom(
                                    'Đã giao',
                                    fontSize: 11,
                                    color: ColorsFrave.successColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEarningsRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextCustom(
          label,
          fontSize: isHighlight ? 14 : 13,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          color: isHighlight ? ColorsFrave.darkText : ColorsFrave.greyText,
        ),
        TextCustom(
          value,
          fontSize: isHighlight ? 15 : 13,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
          color: isHighlight ? ColorsFrave.successColor : ColorsFrave.darkText,
        ),
      ],
    );
  }
}
