import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';

/// Visual flavour of the `−  n  +` control.
///
/// The Figma draws the same control twice with inverted colours:
///   * on the orange cart panel the bubble is **white** with an orange glyph
///     (nodes `202:2189` / `202:2739`)
///   * on the light checkout page the bubble is **orange** with a white glyph
///     (nodes `202:1599` / `202:1607`)
enum CartStepperStyle {
  /// White bubble, orange glyph — used on the orange cart panel.
  onOrange,

  /// Orange bubble, white glyph — used on the light checkout page.
  onLight,
}

/// The `−  n  +` pill from Figma node `202:2189` (Cart) and `202:1599`
/// (Checkout).
///
/// Geometry taken from the Figma frames:
///   * cart      — pill 47 x 16, radius 10, icons 14 px
///   * checkout  — pill 64.6 x 22, radius 10, icons 19.25 px
///
/// The pill itself has **no fill** in Figma; the bubble around each glyph
/// comes from the SVG. That is why this widget draws no background of its
/// own — only the icons and the centred count.
///
/// The `−` button is always enabled: tapping it at quantity 1 removes the
/// line from the cart (the bloc drops a line whose quantity reaches 0), so
/// the user never has to reach for a separate delete affordance. On the
/// checkout page Figma swaps in a *peach* glyph for that state (node
/// `202:1607`), which this widget reproduces.
class CartQuantityStepper extends StatelessWidget {
  const CartQuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    this.style = CartStepperStyle.onOrange,
    this.width = 47,
    this.height = 16,
    this.iconSize = 14,
    this.textSize = 13,
    this.textColor = ColorsFrave.onOrange,
  });

  /// Current count shown in the middle.
  final int quantity;

  /// Fired when the `+` button is tapped.
  final VoidCallback onIncrease;

  /// Fired when the `−` button is tapped. At quantity 1 the line is removed
  /// from the cart.
  final VoidCallback onDecrease;

  /// Which colour scheme to use.
  final CartStepperStyle style;

  /// Total width of the control.
  final double width;

  /// Height of the control.
  final double height;

  /// Size of the `−` / `+` SVGs.
  final double iconSize;

  /// Font size of the count.
  final double textSize;

  /// Colour of the count text.
  final Color textColor;

  /// Assets for the two glyphs, picked by [style].
  String get _lessAsset {
    if (style == CartStepperStyle.onOrange) {
      return 'assets/figma_cart/qty_less.svg';
    }
    // Figma draws a peach `−` once the count reaches 1 (node `202:1607`).
    return quantity > 1
        ? 'assets/figma_cart/qty_less_checkout.svg'
        : 'assets/figma_cart/qty_less_checkout2.svg';
  }

  String get _addAsset => style == CartStepperStyle.onOrange
      ? 'assets/figma_cart/qty_add.svg'
      : 'assets/figma_cart/qty_add_checkout.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _StepIcon(
            asset: _lessAsset,
            size: iconSize,
            enabled: true,
            onTap: onDecrease,
            semanticLabel: context.l10n.actionDecreaseQuantity,
          ),
          Expanded(
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'LeagueSpartan',
                fontSize: textSize,
                fontWeight: FontWeight.w400,
                color: textColor,
                height: 1,
              ),
            ),
          ),
          _StepIcon(
            asset: _addAsset,
            size: iconSize,
            enabled: true,
            onTap: onIncrease,
            semanticLabel: context.l10n.actionIncreaseQuantity,
          ),
        ],
      ),
    );
  }
}

/// The `−` / `+` glyph inside the pill.
class _StepIcon extends StatelessWidget {
  const _StepIcon({
    required this.asset,
    required this.size,
    required this.enabled,
    required this.onTap,
    required this.semanticLabel,
  });

  final String asset;
  final double size;
  final bool enabled;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }
}

/// The small orange trash glyph used on the checkout page (node `202:1579`).
class CartDeleteButton extends StatelessWidget {
  const CartDeleteButton({super.key, required this.onTap, this.size = 12});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.actionRemoveItem,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: SvgPicture.asset(
            'assets/figma_cart/trash_icon.svg',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
