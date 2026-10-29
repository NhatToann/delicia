import 'package:flutter/material.dart';

import '../../../../domain/models/product_cart.dart';
import '../../../helpers/category_assets.dart';
import '../../../helpers/image_resolver.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import 'cart_quantity_stepper.dart';

/// One product line in the cart panel (Figma nodes `202:2189` / `202:2739`).
///
/// Figma places every element of the row at an absolute position, so the
/// row is built as a stack of fixed offsets relative to the thumbnail's
/// top-left corner:
///
///   thumbnail  80 x 80, radius 20            (0, 0)
///   name       League Spartan Medium 15, #F8F8F8, letter-spacing 0.45,
///              81 px wide box so it wraps exactly like the design
///                                            (89, 14)
///   date       League Spartan Medium 13, #FFFFFF, right aligned
///              ("29/11/24" then "15:00")      (right edge, 14)
///   price      League Spartan Light 14, #F8F8F8
///                                            (87, 47)
///   stepper    47 x 16 pill                  (213, 45)
///
/// The row is 260 px wide — the Figma content box between the thumbnail
/// (x33) and the right edge of the panel content (x293).
///
/// Every price shown here is derived from [ProductCart.price] — nothing is
/// hardcoded.
class CartItemRow extends StatelessWidget {
  const CartItemRow({
    super.key,
    required this.product,
    required this.onIncrease,
    required this.onDecrease,
    this.onDelete,
    this.addedAt,
  });
  /// The cart entry this row renders.
  final ProductCart product;

  /// Increments the quantity of this line.
  final VoidCallback onIncrease;

  /// Decrements the quantity of this line.
  final VoidCallback onDecrease;

  /// Removes the line from the cart. When null no delete affordance shows.
  final VoidCallback? onDelete;

  /// When the line was added. Figma shows a date + time pair next to the
  /// name; when the caller has no timestamp the row simply omits it.
  final DateTime? addedAt;

  /// Width of the row — the Figma content box, x33 to x293.
  static const double rowWidth = 260;

  /// Size of the thumbnail.
  static const double thumbSize = 80;

  /// Width of the product-name text box.
  ///
  /// Figma draws both product names in an 81 px box, which is what makes
  /// "Strawberry Shake" wrap onto two lines. The same width is used here so
  /// the panel reads exactly like the design.
  static const double nameWidth = 81;

  /// Offset of the name / date block from the thumbnail's top-left corner.
  static const double headerOffset = 14;

  /// Height of the name block — two lines of League Spartan Medium 15 with
  /// the Figma's 101.45 % line height.
  static const double nameBlockHeight = 30.44;

  /// Offset of the price from the thumbnail's top-left corner.
  static const double priceOffset = 47;

  /// Offset of the stepper from the thumbnail's top-left corner.
  static const double stepperOffset = 45;

  /// Line total = unit price × quantity.
  double get lineTotal => product.price * product.quantity;

  @override
  Widget build(BuildContext context) {
    // A dish ordered in two different sizes is two cart lines, and each
    // line says which size it is.
    final sizeLabel = product.optionLabel?.trim();
    final hasSize = sizeLabel != null && sizeLabel.isNotEmpty;

    return SizedBox(
      width: rowWidth,
      height: thumbSize,
      child: Stack(
        children: <Widget>[
          // ---- thumbnail (80 x 80, radius 20) ----
          Positioned(
            left: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: thumbSize,
                height: thumbSize,
                child: ImageResolver.resolveWidget(
                  product.imageProduct,
                  fit: BoxFit.cover,
                  fallback: CategoryAssets.pool.first,
                ),
              ),
            ),
          ),
          // ---- name (+ the selected size) ----
          Positioned(
            left: 89,
            top: headerOffset,
            width: nameWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  product.nameProduct,
                  maxLines: hasSize ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(
                    15,
                    color: ColorsFrave.onOrange,
                    height: 15.22 / 15,
                  ).copyWith(letterSpacing: 0.45),
                ),
                if (hasSize) ...<Widget>[
                  const SizedBox(height: 2),
                  Text(
                    sizeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FraveText.light(
                      12,
                      color: ColorsFrave.onOrange,
                      height: 12.6 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          // ---- added-at stamp ----
          if (addedAt != null)
            Positioned(
              right: 0,
              top: headerOffset,
              child: _AddedAt(timestamp: addedAt!),
            ),
          // ---- price ----
          Positioned(
            left: 87,
            top: priceOffset,
            child: Text(
              Money.format(lineTotal),
              maxLines: 1,
              style: FraveText.light(
                14,
                color: ColorsFrave.onOrange,
                height: 1,
              ),
            ),
          ),
          // ---- quantity stepper ----
          Positioned(
            left: 213,
            top: stepperOffset,
            child: CartQuantityStepper(
              quantity: product.quantity,
              onIncrease: onIncrease,
              onDecrease: onDecrease,
            ),
          ),
        ],
      ),
    );
  }
}

/// The `29/11/24` + `15:00` pair Figma puts on the right of each cart row.
class _AddedAt extends StatelessWidget {
  const _AddedAt({required this.timestamp});

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    String two(int n) => n.toString().padLeft(2, '0');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '${two(timestamp.day)}/${two(timestamp.month)}/'
          '${timestamp.year % 100}',
          style: FraveText.medium(
            13,
            color: ColorsFrave.onOrange,
            height: 13.85 / 13,
          ),
        ),
        Text(
          '${two(timestamp.hour)}:${two(timestamp.minute)}',
          style: FraveText.medium(
            13,
            color: ColorsFrave.onOrange,
            height: 13.85 / 13,
          ),
        ),
      ],
    );
  }
}
