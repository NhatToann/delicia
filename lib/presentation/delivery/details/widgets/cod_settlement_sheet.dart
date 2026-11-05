import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../components/text_custom.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';

/// The cash-on-delivery settlement step.
///
/// The app has exactly one payment method: the customer hands over cash
/// when the courier knocks on the door. Nothing in the system records that
/// moment by itself, so the courier has to confirm it — and the amount
/// they actually took, which is not necessarily the amount the customer
/// was quoted (a round sum, a missing coin, a wrong item).
///
/// This sheet collects that confirmation and hands the collected amount
/// back to the caller. It never writes to the database itself: the
/// settlement travels through the bloc, like every other write.
class CodSettlementSheet extends StatefulWidget {
  /// The order being settled.
  final OrderRecord order;

  const CodSettlementSheet({super.key, required this.order});

  @override
  State<CodSettlementSheet> createState() => _CodSettlementSheetState();
}

class _CodSettlementSheetState extends State<CodSettlementSheet> {
  late final TextEditingController _controller;

  /// The amount the customer was quoted — what the courier expects to
  /// receive at the door.
  late final int _amountDue;

  /// The amount currently typed in the field, or `null` while it holds
  /// something that is not a number.
  int? _collected;

  /// True when the typed amount differs from the quoted amount.
  bool get _isMismatch =>
      _collected != null && _collected != _amountDue && _amountDue > 0;

  @override
  void initState() {
    super.initState();
    _amountDue = widget.order.codAmountVnd;
    _controller = TextEditingController(text: Money.formatPlain(_amountDue));
    _collected = _amountDue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reads the field back with [Money.parseVnd], so the number the courier
  /// sees is exactly the number that gets recorded — no hand-rolled
  /// formatting, no second rounding.
  void _onChanged(String _) {
    final parsed = Money.parseVnd(_controller.text);
    setState(() => _collected = parsed);
  }

  void _confirm() {
    final collected = _collected;
    if (collected == null || collected < 0) return;
    Navigator.of(context).pop(collected);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextCustom(
            l10n.codSettlementTitle,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          const SizedBox(height: 6),
          TextCustom(
            l10n.codSettlementSubtitle,
            color: ColorsFrave.greyText,
            fontSize: 13,
          ),
          const SizedBox(height: 20),

          // Amount the customer has to hand over.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: ColorsFrave.pillYellow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextCustom(
                    l10n.codSettlementAmountDue,
                    fontSize: 13,
                    color: ColorsFrave.ink,
                  ),
                ),
                TextCustom(
                  Money.format(_amountDue),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: ColorsFrave.primaryColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Amount actually collected — editable, because it can differ.
          TextCustom(
            l10n.codSettlementCollectedLabel,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            onChanged: _onChanged,
            keyboardType: TextInputType.number,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: l10n.codSettlementCollectedHint,
              prefixText: '${Money.symbol} ',
              prefixStyle: const TextStyle(
                fontSize: 16,
                color: ColorsFrave.greyText,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ColorsFrave.dividerOrange),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ColorsFrave.dividerOrange),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: ColorsFrave.primaryColor),
              ),
            ),
          ),

          if (_isMismatch) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: ColorsFrave.errorColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: TextCustom(
                    l10n.codSettlementMismatch,
                    color: ColorsFrave.errorColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),

          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.successColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: (_collected == null || _collected! < 0) ? null : _confirm,
            child: TextCustom(
              l10n.codSettlementConfirm,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
