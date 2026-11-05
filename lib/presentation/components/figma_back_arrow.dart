import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../helpers/l10n_extension.dart';
import '../helpers/navigation_helper.dart';
import '../themes/colors_frave.dart';

/// The back chevron every Figma client screen opens with.
///
/// The kit draws it as a thin 8 x 13 stroke arrow at **x35 / y81** in
/// `#E95322` — the exact artwork in `assets/figma_cart/back_arrow.svg`.
///
/// The visible glyph is only 8 px wide, so it would be a miserable tap
/// target. The widget therefore stacks two layers:
///
///   * a transparent 48 x 48 [InkWell] that carries the touch, and
///   * the 8 x 13 SVG, positioned exactly on the Figma coordinates and
///     carrying the accessibility label.
///
/// The glyph is centred inside the 48 x 48 target, so the target sits at
/// x15 / y63.5 and the ink lands on x35 / y81.
class FigmaBackArrow extends StatelessWidget {
  const FigmaBackArrow({
    super.key,
    this.onPressed,
    this.fallbackRoute = '/client/home',
  });

  /// Fired when the chevron is tapped. Defaults to [goBack].
  final VoidCallback? onPressed;

  /// Where the chevron goes when there is nothing to pop.
  final String fallbackRoute;

  /// Width of the Figma glyph.
  static const double glyphWidth = 8;

  /// Height of the Figma glyph.
  static const double glyphHeight = 13;

  /// Size of the invisible touch target.
  static const double targetSize = 48;

  /// The artwork Figma uses for the chevron.
  static const String assetPath = 'assets/figma_cart/back_arrow.svg';

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: targetSize,
      child: Stack(
        children: <Widget>[
          // The touch layer — the whole 48 x 48 square is tappable.
          Positioned.fill(
            child: InkWell(
              onTap:
                  onPressed ?? () => goBack(context, fallback: fallbackRoute),
              borderRadius: BorderRadius.circular(targetSize / 2),
              child: const SizedBox.expand(),
            ),
          ),
          // The glyph — placed on the Figma coordinates.
          Positioned(
            left: (targetSize - glyphWidth) / 2,
            top: (targetSize - glyphHeight) / 2,
            child: Semantics(
              button: true,
              label: context.l10n.actionBack,
              child: SvgPicture.asset(
                assetPath,
                width: glyphWidth,
                height: glyphHeight,
                // The SVG already carries the kit's `#E95322`; the filter
                // only keeps it in step with the theme.
                colorFilter: const ColorFilter.mode(
                  ColorsFrave.navOrange,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
