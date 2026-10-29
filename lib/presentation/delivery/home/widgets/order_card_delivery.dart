import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/delivery_status.dart';
import '../../../../domain/models/order_record.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';

class OrderCardDelivery extends StatelessWidget {
  final OrderRecord order;
  final bool isAvailableTab;
  final VoidCallback onTap;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onNavigateMap;

  const OrderCardDelivery({
    super.key,
    required this.order,
    this.isAvailableTab = false,
    required this.onTap,
    this.onAccept,
    this.onReject,
    this.onNavigateMap,
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
    final timeFormat = DateFormat('MMM dd, yyyy • HH:mm');

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
                      'Order #$shortId',
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
                    status.label,
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
                    order.street.isNotEmpty ? order.street : 'Address not specified',
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
                      'Amount to Collect',
                      fontSize: 11,
                      color: ColorsFrave.greyText,
                    ),
                    TextCustom(
                      '\$${order.amount.toStringAsFixed(2)}',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: ColorsFrave.primaryColor,
                    ),
                  ],
                ),

                // Actions based on tab
                if (isAvailableTab)
                  Row(
                    children: [
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
                          'Accept Order',
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
                      if (onReject != null &&
                          (status == DeliveryStatus.accepted ||
                              status == DeliveryStatus.pending))
                        TextButton(
                          onPressed: onReject,
                          child: const TextCustom(
                            'Reject',
                            color: ColorsFrave.errorColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          icon: const Icon(
                            Icons.navigation_outlined,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const TextCustom(
                            'Map',
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                          onPressed: onNavigateMap,
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
