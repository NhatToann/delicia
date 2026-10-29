import 'package:flutter/material.dart';

import '../../../../domain/models/product_option.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// One selectable size / portion of a dish.
///
/// Figma node `192:1216` draws the size list as four rows, each with:
///
///   label      x35, League Spartan Medium 13, ink
///   price      right-aligned at x331, League Spartan Light 12, grey
///   radio      x341..355, a 15 px circle — orange with a white centre
///              when the row is selected, a plain peach ring otherwise
///   divider    a 1 px peach rule under the row
///
/// The prices come from the database — every [ProductOption] carries its
/// own absolute price — so nothing here is hardcoded.
class ProductSizeRow extends StatelessWidget {
  const ProductSizeRow({
    super.key,
    required this.option,
    required this.selected,
    required this.onTap,
  });

  /// The size this row offers.
  final ProductOption option;

  /// Whether this row is the one the customer picked.
  final bool selected;

  /// Fired when the row is tapped.
  final VoidCallback onTap;

  /// Diameter of the radio button (Figma 15).
  static const double radioSize = 15;

  /// Height of the row — the Figma rows are 31 px apart.
  static const double rowHeight = 31;

  /// Colour of the unselected radio's ring.
  static const Color radioIdle = Color(0xFFFFDECF);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: context.l10n.productSizeSelect(option.label),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: rowHeight,
          child: Row(
            children: <Widget>[
              // ---- label ----
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(
                    13,
                    color: ColorsFrave.ink,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // ---- price ----
              Text(
                Money.format(option.price),
                maxLines: 1,
                // The row is a fixed height, so the price has to give way
                // rather than overflow it when the text scale is large.
                overflow: TextOverflow.ellipsis,
                style: FraveText.light(
                  12,
                  color: ColorsFrave.greyText,
                  height: 1,
                ),
              ),
              const SizedBox(width: 12),
              // ---- radio ----
              _Radio(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

/// The little circle at the end of a size row.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ProductSizeRow.radioSize,
      height: ProductSizeRow.radioSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? ColorsFrave.navOrange : Colors.transparent,
        border: Border.all(
          color: selected ? ColorsFrave.navOrange : ProductSizeRow.radioIdle,
          width: 1.5,
        ),
      ),
      child: selected
          ? Container(
              margin: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ColorsFrave.onOrange,
              ),
            )
          : null,
    );
  }
}
