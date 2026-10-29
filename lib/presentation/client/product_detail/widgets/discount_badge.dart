import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The starburst discount badge Figma draws over the product photo.
///
/// Figma node `192:1216` shows a 16-point starburst in the top-right
/// corner of the picture reading "-30%". The **shape** is the SVG asset
/// `discount_badge.svg`; the **number** comes from
/// [Productsdb.discountPercent], which derives it from the product's own
/// `oldPrice` and `price` — so it is never a hardcoded constant.
///
/// The badge disappears entirely when the dish is not on offer.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge({super.key, required this.percent});

  /// The discount to show, as a whole percentage.
  ///
  /// Always comes from the product row (see `Productsdb.discountPercent`).
  final int percent;

  /// Diameter of the badge (Figma 56).
  static const double badgeSize = 56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.productDetailDiscount(percent),
      child: SizedBox(
        width: badgeSize,
        height: badgeSize,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            SvgPicture.asset(
              'assets/figma_product/discount_badge.svg',
              width: badgeSize,
              height: badgeSize,
              fit: BoxFit.contain,
            ),
            // The percentage sits in the middle of the starburst. It is
            // scaled down rather than clipped so it always stays inside
            // the badge, whatever the text scale is.
            Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '-$percent%',
                  maxLines: 1,
                  softWrap: false,
                  style: FraveText.bold(
                    13,
                    color: ColorsFrave.onOrange,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
