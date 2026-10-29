import 'package:flutter/material.dart';

import '../../../../data/env/environment.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The Subtotal / Tax and Fees / Delivery / Total block.
///
/// Figma node `202:1804` (cart panel) and `202:3084` (checkout page).
///
/// The five rows are laid out on a fixed vertical rhythm, taken from the
/// Figma frames:
///
///   cart panel   "Subtotal"  y476 · "Tax and Fees" y520 · "Delivery" y561
///                dashed rule y599 · "Total" y620
///   checkout     "Subtotal"  y665 · "Tax and Fees" y709 · "Delivery" y750
///                dashed rule y788 · "Total" y809
///
/// Both frames use the same offsets (0 / 44 / 85 / 123 / 144), so the two
/// surfaces share one rhythm. Each row sits in a fixed-height slot and the
/// text is aligned to the top of that slot, which keeps the rhythm exact
/// regardless of the font's own metrics.
///
/// Every label and value is League Spartan Medium 20. On the orange panel
/// both are `#F8F8F8`; on the light checkout page both are `#391713`.
///
/// **Every amount is derived** — the subtotal comes from the real product
/// prices, and tax / delivery / total come from [CartPricing]. The Figma
/// values (`$32.00`, `$5.00`, `$3.00`, `$40.00`) are layout samples only and
/// are deliberately not reproduced here.
class CartSummary extends StatelessWidget {
  const CartSummary({
    super.key,
    required this.subtotal,
    this.labelColor = ColorsFrave.onOrange,
    this.valueColor = ColorsFrave.onOrange,
    this.labelSize = 20,
    this.valueSize = 20,
    this.showDivider = true,
    this.dividerColor = ColorsFrave.orangeSoft,
  });

  /// Sum of price × quantity across the cart.
  final double subtotal;

  /// Colour of the row labels.
  final Color labelColor;

  /// Colour of the row values.
  final Color valueColor;

  /// Font size of the row labels.
  final double labelSize;

  /// Font size of the row values.
  final double valueSize;

  /// Whether the dashed rule above the Total row is drawn.
  final bool showDivider;

  /// Colour of the dashed rule. `#FFDECF` on both surfaces.
  final Color dividerColor;

  /// Distance from the "Subtotal" row to the "Tax and Fees" row.
  static const double pitchSubtotalToTax = 44;

  /// Distance from the "Tax and Fees" row to the "Delivery" row.
  static const double pitchTaxToDelivery = 41;

  /// Distance from the "Delivery" row to the dashed rule.
  static const double pitchDeliveryToRule = 38;

  /// Thickness of the dashed rule.
  static const double ruleThickness = 2;

  /// Distance from the rule to the "Total" row.
  static const double pitchRuleToTotal = 19;

  /// Height of the "Total" row slot.
  static const double totalSlotHeight = 22;

  /// Tax charged on the subtotal.
  double get tax => CartPricing.taxOf(subtotal);

  /// Flat delivery fee.
  double get delivery => CartPricing.deliveryFee;

  /// Grand total = subtotal + tax + delivery.
  double get total => CartPricing.totalOf(subtotal);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _SummarySlot(
          height: pitchSubtotalToTax,
          label: context.l10n.cartSummarySubtotal,
          value: subtotal,
          labelColor: labelColor,
          valueColor: valueColor,
          labelSize: labelSize,
          valueSize: valueSize,
        ),
        _SummarySlot(
          height: pitchTaxToDelivery,
          label: context.l10n.cartSummaryTax,
          value: tax,
          labelColor: labelColor,
          valueColor: valueColor,
          labelSize: labelSize,
          valueSize: valueSize,
        ),
        _SummarySlot(
          height: pitchDeliveryToRule,
          label: context.l10n.cartSummaryDelivery,
          value: delivery,
          labelColor: labelColor,
          valueColor: valueColor,
          labelSize: labelSize,
          valueSize: valueSize,
        ),
        if (showDivider)
          // Figma draws the rule as a dashed peach line (Line 4).
          CustomPaint(
            size: const Size(double.infinity, ruleThickness),
            painter: _DashedRulePainter(color: dividerColor),
          ),
        SizedBox(height: pitchRuleToTotal),
        _SummarySlot(
          height: totalSlotHeight,
          label: context.l10n.cartSummaryTotal,
          value: total,
          labelColor: labelColor,
          valueColor: valueColor,
          labelSize: labelSize,
          valueSize: valueSize,
        ),
      ],
    );
  }
}

/// One `label ............ value` line inside a fixed-height slot.
///
/// The slot has a fixed height and the text is aligned to its top, so the
/// vertical rhythm of the block is decided by the layout and not by the
/// font metrics.
class _SummarySlot extends StatelessWidget {
  const _SummarySlot({
    required this.height,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
    required this.labelSize,
    required this.valueSize,
  });

  final double height;
  final String label;
  final double value;
  final Color labelColor;
  final Color valueColor;
  final double labelSize;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: FraveText.medium(
                labelSize,
                color: labelColor,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.format(value),
            maxLines: 1,
            style: FraveText.medium(
              valueSize,
              color: valueColor,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// The dashed hairline Figma draws above the Total row.
///
/// Figma's `Line 4` is a 2 px dashed path in `#FFDECF`; a plain [Divider]
/// would render a solid rule, so the dashes are painted by hand.
class _DashedRulePainter extends CustomPainter {
  const _DashedRulePainter({required this.color});

  final Color color;

  /// Length of one dash, matching the Figma path (2 units on / 2 units off).
  static const double _dash = 2;
  static const double _gap = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    final step = _dash + _gap;
    for (var x = 0.0; x < size.width; x += step) {
      canvas.drawLine(
        Offset(x, y),
        Offset((x + _dash).clamp(0, size.width), y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRulePainter oldDelegate) =>
      oldDelegate.color != color;
}
