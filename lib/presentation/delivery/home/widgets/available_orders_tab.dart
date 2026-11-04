import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';
import 'order_card_delivery.dart';

class AvailableOrdersTab extends StatelessWidget {
  final List<OrderRecord> orders;
  final bool isLoading;
  final bool hasActiveDelivery;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderRecord> onAccept;
  final ValueChanged<OrderRecord>? onReject;
  final ValueChanged<OrderRecord> onTap;

  const AvailableOrdersTab({
    super.key,
    required this.orders,
    required this.isLoading,
    this.hasActiveDelivery = false,
    required this.onRefresh,
    required this.onAccept,
    this.onReject,
    required this.onTap,
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
                  hasActiveDelivery
                      ? Icons.delivery_dining_rounded
                      : Icons.storefront_outlined,
                  size: 64,
                  color: hasActiveDelivery
                      ? ColorsFrave.primaryColor.withValues(alpha: 0.7)
                      : Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                TextCustom(
                  hasActiveDelivery
                      ? 'Đang có đơn hàng cần giao'
                      : 'Hiện không có đơn hàng khả dụng',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorsFrave.darkText,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                TextCustom(
                  hasActiveDelivery
                      ? 'Vui lòng hoàn thành đơn hàng hiện tại để tiếp tục nhận đơn mới.'
                      : 'Kéo xuống để làm mới hoặc quay lại sau!',
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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final order = orders[index];
          return OrderCardDelivery(
            order: order,
            isAvailableTab: true,
            onTap: () => onTap(order),
            onAccept: () => onAccept(order),
            onReject: onReject != null ? () => onReject!(order) : null,
          );
        },
      ),
    );
  }
}
