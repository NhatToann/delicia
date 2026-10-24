import 'package:flutter/material.dart';

import '../../../../domain/models/address.dart';
import '../../../components/text_custom.dart';
import '../../../themes/colors_frave.dart';

/// AddressSelector — radio list of addresses used inside the checkout
/// flow. The current selection is highlighted in [PickersColors.primaryColor]
/// and the empty-state prompts the user to add an address via the
/// placeholder list (UC-06 will plug the real list).
class AddressSelector extends StatelessWidget {
  final List<Address> addresses;
  final String? selectedId;
  final ValueChanged<Address> onSelect;

  const AddressSelector({
    super.key,
    required this.addresses,
    required this.selectedId,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (addresses.isEmpty) {
      return const _EmptyAddress();
    }
    final effective = selectedId ?? addresses.first.id;
    return Column(
      children: addresses.map((a) {
        final isSelected = a.id == effective;
        return InkWell(
          onTap: () => onSelect(a),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: isSelected
                  ? ColorsFrave.primaryColor.withValues(alpha: 0.06)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? ColorsFrave.primaryColor
                    : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected
                      ? ColorsFrave.primaryColor
                      : ColorsFrave.greyText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextCustom(
                        a.street,
                        fontWeight: FontWeight.w600,
                      ),
                      if (a.reference.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        TextCustom(
                          a.reference,
                          fontSize: 13,
                          color: ColorsFrave.greyText,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _EmptyAddress extends StatelessWidget {
  const _EmptyAddress();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsFrave.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: const [
          Icon(Icons.location_off_outlined, color: ColorsFrave.greyText),
          SizedBox(width: 8),
          Expanded(
            child: TextCustom(
              'No saved address. Add one in your profile.',
              color: ColorsFrave.greyText,
            ),
          ),
        ],
      ),
    );
  }
}