import 'package:flutter/material.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import '../payment_geometry.dart';

/// The little peach "Edit" chip (Figma nodes `286:1856` / `286:1860`).
///
/// 58 x 14 with a 38 px radius, a `#FFDECF` fill and a 6 px `#E95322`
/// label with a `-0.03` tracking. Figma centres the label in the chip's
/// 8.5 px line box, which is why the label uses a 5 px leading.
class PaymentEditChip extends StatelessWidget {
  const PaymentEditChip({super.key, required this.onTap});

  /// Fired when the chip is tapped.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.actionEdit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: PaymentGeometry.editChipWidth,
          height: PaymentGeometry.editChipHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ColorsFrave.orangeSoft,
            borderRadius: BorderRadius.circular(38),
          ),
          child: Text(
            context.l10n.actionEdit,
            maxLines: 1,
            style: FraveText.regular(
              PaymentGeometry.editChipFontSize,
              color: ColorsFrave.navOrange,
              height:
                  PaymentGeometry.editChipLeading /
                      PaymentGeometry.editChipFontSize,
              letterSpacing: PaymentGeometry.editChipTracking,
            ),
          ),
        ),
      ),
    );
  }
}

/// The hairline Figma draws between the payment sections (`#FFD8C7`).
class PaymentDivider extends StatelessWidget {
  const PaymentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: ColorsFrave.dividerOrange);
  }
}
