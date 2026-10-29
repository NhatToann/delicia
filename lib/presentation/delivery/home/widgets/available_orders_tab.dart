import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';
import 'order_card_delivery.dart';

class AvailableOrdersTab extends StatelessWidget {
  final List<OrderRecord> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final ValueChanged<OrderRecord> onAccept;
  final ValueChanged<OrderRecord> onTap;

  const AvailableOrdersTab({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.onAccept,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                const TextCustom(
                  'No available orders at the moment',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: ColorsFrave.darkText,
                ),
                const SizedBox(height: 4),
                const TextCustom(
                  'Pull down to refresh or check back soon!',
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
            isAvailableTab: true,
            onTap: () => onTap(order),
            onAccept: () => onAccept(order),
          );
        },
      ),
    );
  }
}
