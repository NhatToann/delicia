import 'package:flutter/material.dart';

import '../helpers/navigation_helper.dart';
import '../themes/colors_frave.dart';
import '../themes/type_frave.dart';
import 'figma_back_arrow.dart';

/// The yellow header band every Figma client screen opens with.
///
/// The Food Delivery UI Kit draws a full-bleed `#F5CB58` band behind the
/// status bar, with a small back chevron on the left and a centred
/// League Spartan Bold title:
///
///   band      y0 → y129 (the top 32 px is the system status bar)
///   arrow     x35  y81   8 x 13   (#E95322)
///   title     centred  League Spartan Bold 28 (#F8F8F8)
///
/// The band height is fixed so the content below always starts at the same
/// place, whatever the device's status-bar height is.
class FigmaHeaderBand extends StatelessWidget {
  const FigmaHeaderBand({
    super.key,
    required this.title,
    this.onBack,
    this.fallbackRoute = '/client/home',
    this.actions = const <Widget>[],
  });

  /// The centred title (already localized by the caller).
  final String title;

  /// Fired when the back chevron is tapped. Defaults to [goBack].
  final VoidCallback? onBack;

  /// Where the back chevron goes when there is nothing to pop.
  final String fallbackRoute;

  /// Optional trailing widgets (a refresh button, an "add" action, …).
  final List<Widget> actions;

  /// Figma: the system status bar in the mockups is 32 px tall.
  static const double figmaStatusBarHeight = 32;

  /// Figma: the band is 129 px tall in total, so 97 px of content sits
  /// below the status bar.
  static const double bandContentHeight = 97;

  /// The horizontal gutter used across the kit's client screens.
  static double gutterFor(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 380 ? 20.0 : 35.0;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final bandHeight =
        (topInset > figmaStatusBarHeight ? topInset : figmaStatusBarHeight) +
        bandContentHeight;
    final gutter = gutterFor(context);

    return SizedBox(
      height: bandHeight,
      child: ColoredBox(
        color: ColorsFrave.headerYellow,
        child: Stack(
          children: <Widget>[
            // The back chevron — the Figma glyph (8 x 13 at x35 / y81)
            // inside a 48 x 48 touch target.
            Positioned(
              left: gutter - 20,
              top: 63.5,
              child: FigmaBackArrow(
                onPressed:
                    onBack ?? () => goBack(context, fallback: fallbackRoute),
                fallbackRoute: fallbackRoute,
              ),
            ),
            // Title — Figma: centred on the frame.
            Positioned(
              left: gutter + 20,
              right: gutter + 20,
              top: 73,
              bottom: 0,
              child: Align(
                alignment: Alignment.topCenter,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: FraveText.bold(
                      28,
                      color: ColorsFrave.onOrange,
                      height: 1.0,
                    ),
                  ),
                ),
              ),
            ),
            // Trailing actions sit on the same baseline as the title.
            if (actions.isNotEmpty)
              Positioned(
                right: gutter - 12,
                top: 58,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}
