import 'package:flutter/material.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../helpers/navigation_helper.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import '../payment_geometry.dart';

/// The yellow header band of the Payment screen (Figma node `202:2960`).
///
/// The band is the Figma frame's 32 px status bar plus 100 px of content, so
/// the title and the back arrow can be placed at their absolute Figma
/// coordinates and the layout matches the frame pixel for pixel.
class PaymentHeader extends StatelessWidget {
  const PaymentHeader({super.key});

  /// Height of the status bar the Figma frame reserves.
  static const double figmaStatusBarHeight = 32;

  /// Height of the yellow band *below* the status bar.
  static const double bandContentHeight = 100;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final offset =
        topInset > figmaStatusBarHeight ? topInset : figmaStatusBarHeight;

    return SizedBox(
      height: offset + bandContentHeight,
      child: ColoredBox(
        color: ColorsFrave.headerYellow,
        child: Stack(
          children: <Widget>[
            // Back arrow — Figma x35, y81 (8 x 13). The glyph is placed
            // exactly on its node box; the SVG's own stroke padding then
            // puts the ink at x36..41 / y82..92, as in the Figma PNG.
            Positioned(
              left: 12,
              top: offset +
                  (PaymentGeometry.backArrowTop - figmaStatusBarHeight) -
                  17.5,
              child: _BackButton(onPressed: () => goBack(
                    context,
                    fallback: '/client/cart',
                  )),
            ),
            // Title — Figma centres it on the 393 px frame, text box at y73.
            //
            // Figma's node box is 26 px tall while the title is a 28 px
            // label, so the line box is set to 26 px (26 / 28) and the box
            // is pinned to the node's top edge — that is what lands the
            // glyphs on y74..98, exactly like the PNG.
            Positioned(
              left: 0,
              right: 0,
              top: offset + (PaymentGeometry.titleTop - figmaStatusBarHeight),
              height: PaymentGeometry.titleLeading,
              child: Center(
                child: Text(
                  context.l10n.paymentTitle,
                  style: FraveText.bold(
                    PaymentGeometry.titleSize,
                    color: ColorsFrave.onOrange,
                    height: PaymentGeometry.textHeight(
                      leading: PaymentGeometry.titleLeading,
                      fontSize: PaymentGeometry.titleSize,
                    ),
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

/// The back arrow (Figma node `85:3032`).
///
/// The glyph is 8 x 13 at x35 / y81. A larger transparent target sits on
/// top of it so the control is comfortable to hit, while the visible
/// glyph keeps its exact Figma position.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: IconButton(
        tooltip: context.l10n.actionBack,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: const Icon(
          Icons.arrow_back_rounded,
          size: 22,
          color: ColorsFrave.primaryColor,
        ),
      ),
    );
  }
}
