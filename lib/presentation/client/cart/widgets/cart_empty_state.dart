import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The empty-cart body — Figma node `202:2213` ("4.3 - A - Cart").
///
/// Figma places the two elements at absolute positions on the 393 x 852
/// frame:
///
///   illustration 184 x 184, radius 51.5, at x135 y308
///   headline    "Want to add something?"  League Spartan Bold 24, #FFFFFF,
///               two lines, at x149 y502
///
/// This widget is rendered directly below the panel header, so the frame
/// coordinates are converted to body-local offsets using [bodyTop] — the
/// frame y where the header ends.
///
/// The "Your cart is empty" subtitle is **not** drawn here — Figma places it
/// in the panel header, right under the yellow rule, so it lives in
/// `CartPanel` instead.
///
/// The frame has **no** call-to-action button — the user dismisses the
/// drawer by tapping the backdrop. The illustration is scaled down on short
/// devices so the headline never overflows.
class CartEmptyState extends StatelessWidget {
  const CartEmptyState({super.key});

  /// Frame y where the panel header ends and this body begins.
  ///
  /// The header is `top 66 + 40.3 icon + 38.85 + 1 rule + 18.85 + 22`
  /// tall, and the subtitle that ends it sits at frame y165.
  static const double bodyTop = 187;

  /// Top of the illustration on the reference frame.
  static const double artTop = 308;

  /// Size of the basket illustration on the reference frame.
  static const double artSize = 184;

  /// Top of the headline on the reference frame.
  static const double headlineTop = 502;

  /// Width of the headline text box.
  ///
  /// Figma draws it 158 px wide, which wraps "Want to add something?" onto
  /// two lines.
  static const double headlineWidth = 158;

  /// Gap between the bottom of the illustration and the headline.
  static const double headlineGap = 10;

  /// Height of the two-line headline.
  static const double headlineHeight = 52;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // The illustration keeps its 184 px on the reference frame and only
        // shrinks when the phone is too short to fit the whole block.
        final art = (constraints.maxHeight - _fixedHeight).clamp(
          110.0,
          artSize,
        );

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Figma: the basket sits at frame y308.
                SizedBox(height: artTop - bodyTop),
                SizedBox(
                  width: art,
                  height: art,
                  child: SvgPicture.asset(
                    'assets/figma_cart/cart_empty_basket.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: headlineGap),
                Center(
                  child: SizedBox(
                    width: headlineWidth,
                    height: headlineHeight,
                    child: Text(
                      context.l10n.cartEmptyHeadline,
                      textAlign: TextAlign.center,
                      style: FraveText.bold(
                        24,
                        color: ColorsFrave.onOrange,
                        height: 26 / 24,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Everything in the block that does not scale with the illustration.
  static const double _fixedHeight =
      (artTop - bodyTop) + headlineGap + headlineHeight + 24;
}
