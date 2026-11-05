import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../domain/models/order_record.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';

/// The "đã thu tiền" badge of a settled cash-on-delivery order.
///
/// It is the visible counterpart of [OrderRecord.cashCollected]: it tells
/// the courier that the money for this order is already in their pocket
/// and shows when it was taken. The collected amount is shown too — when
/// it differs from the quoted total, that difference is exactly what the
/// restaurant has to reconcile, so hiding it would defeat the purpose.
class CodSettlementBadge extends StatelessWidget {
  final OrderRecord order;

  const CodSettlementBadge({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final collectedAt = order.cashCollectedAt;

    // Nothing collected, nothing to announce. The badge is a statement
    // about the money, so it stays silent until there is money to talk
    // about.
    if (!order.cashCollected) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: ColorsFrave.successColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorsFrave.successColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.payments_outlined,
                color: ColorsFrave.successColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              TextCustom(
                l10n.codSettlementBadge,
                color: ColorsFrave.successColor,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ],
          ),
          if (collectedAt > 0) ...[
            const SizedBox(height: 6),
            TextCustom(
              l10n.codSettlementCollectedAt(
                DateFormat('dd/MM/yyyy • HH:mm')
                    .format(DateTime.fromMillisecondsSinceEpoch(collectedAt)),
              ),
              color: ColorsFrave.greyText,
              fontSize: 12,
            ),
          ],
          if (order.collectedAmountVnd > 0) ...[
            const SizedBox(height: 4),
            TextCustom(
              l10n.codSettlementCollectedAmount(
                Money.format(order.collectedAmountVnd),
              ),
              color: ColorsFrave.successColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ],
        ],
      ),
    );
  }
}
