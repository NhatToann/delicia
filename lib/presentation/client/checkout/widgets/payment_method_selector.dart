import 'package:flutter/material.dart';

import '../../../../domain/models/type_payment.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';

/// PaymentMethodSelector — radio list of supported payment methods. The
/// current selection is highlighted with the method's brand colour.
class PaymentMethodSelector extends StatelessWidget {
  final TypePaymentMethod selected;
  final ValueChanged<TypePaymentMethod> onSelected;

  const PaymentMethodSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: typePaymentMethods.map((p) {
        final isSelected = p.uid == selected.uid;
        return InkWell(
          onTap: () => onSelected(p),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected
                  ? p.color.withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? p.color : ColorsFrave.backgroundColor,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? p.color : ColorsFrave.greyText,
                ),
                const SizedBox(width: 10),
                Icon(p.icon, color: p.color, size: 28),
                const SizedBox(width: 10),
                Expanded(child: TextCustom(p.type, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}