import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/delivery_status.dart';
import '../../../../domain/models/order_record.dart';
import '../../../../domain/utils/driver_earnings.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';

class OrderCardDelivery extends StatelessWidget {
  final OrderRecord order;
  final bool isAvailableTab;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onNavigateMap;
  final VoidCallback? onDelivered;

  const OrderCardDelivery({
    super.key,
    required this.order,
    this.isAvailableTab = false,
    required this.onTap,
    this.onAccept,
    this.onReject,
    this.onNavigateMap,
    this.onDelivered,
  });

  Color _getStatusColor(DeliveryStatus status) {
    switch (status) {
      case DeliveryStatus.pending:
        return Colors.orange;
      case DeliveryStatus.accepted:
        return Colors.blue;
      case DeliveryStatus.pickedUp:
        return Colors.indigo;
      case DeliveryStatus.onTheWay:
        return Colors.amber.shade800;
      case DeliveryStatus.delivered:
        return ColorsFrave.successColor;
      case DeliveryStatus.cancelled:
        return ColorsFrave.errorColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = DeliveryStatus.fromString(order.status);
    final statusColor = _getStatusColor(status);
    final shortId = order.id.length > 8 ? order.id.substring(0, 8) : order.id;
    final timeFormat = DateFormat('dd/MM/yyyy • HH:mm');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: ID & Status Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.delivery_dining,
                      color: ColorsFrave.primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 6),
                    TextCustom(
                      'Đơn hàng #$shortId',
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextCustom(
                    status.labelVi,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Time
            TextCustom(
              timeFormat.format(order.createdAt),
              color: ColorsFrave.greyText,
              fontSize: 12,
            ),
            const SizedBox(height: 10),

            // Products summary
            TextCustom(
              order.products.map((p) => '${p.quantity}x ${p.nameProduct}').join(', '),
              fontSize: 13,
              color: ColorsFrave.darkText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // Destination address
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: ColorsFrave.primaryColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextCustom(
                    order.street.isNotEmpty ? order.street : 'Chưa xác định địa chỉ',
                    fontSize: 13,
                    color: ColorsFrave.greyText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),

            // Bottom row: Amount & Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TextCustom(
                      'Tiền thu hộ (COD)',
                      fontSize: 11,
                      color: ColorsFrave.greyText,
                    ),
                    TextCustom(
                      Money.format(order.amount),
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: ColorsFrave.primaryColor,
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TextCustom(
                          'Nhận được: ',
                          fontSize: 11,
                          color: ColorsFrave.greyText,
                        ),
                        TextCustom(
                          Money.format(DriverEarnings.earningsVndForOrder(order)),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: ColorsFrave.successColor,
                        ),
                      ],
                    ),
                  ],
                ),

                // Actions based on tab
                if (isAvailableTab)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onReject != null) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: ColorsFrave.errorColor),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                          ),
                          onPressed: onReject,
                          child: const TextCustom(
                            'Từ chối',
                            color: ColorsFrave.errorColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorsFrave.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: onAccept,
                        child: const TextCustom(
                          'Nhận đơn',
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      if (onNavigateMap != null &&
                          status != DeliveryStatus.delivered &&
                          status != DeliveryStatus.cancelled) ...[
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorsFrave.secondaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.navigation_outlined,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: const TextCustom(
                            'Bản đồ',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onPressed: onNavigateMap,
                        ),
                      ],
                      if (onDelivered != null &&
                          status != DeliveryStatus.delivered &&
                          status != DeliveryStatus.cancelled) ...[
                        const SizedBox(width: 6),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: ColorsFrave.successColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.check_circle_outline,
                            size: 15,
                            color: Colors.white,
                          ),
                          label: const TextCustom(
                            'Đã giao',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          onPressed: onDelivered,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
