import 'package:flutter/material.dart';

import '../payment_geometry.dart';

/// How a Figma text node is anchored inside its box.
///
/// Figma has two kinds of text nodes, and they behave differently:
///
///  * **Paragraphs** (`<p>` in the Figma export) are anchored to the *top*
///    of their box — the box's height is the line box's height.
///  * **Auto-layout frames** (`flex flex-col justify-center`) are *centred*
///    in their box. Their box is shorter than the line box, so the glyphs
///    overflow symmetrically above and below it.
///
/// Getting this right is what puts "Order Summary" on y291 even though its
/// node starts at y293.
enum FigmaTextAnchor {
  /// The text is anchored to the top of the node's box.
  top,

  /// The text is centred in the node's box.
  center,
}

/// A label placed exactly where Figma puts it.
///
/// Figma's text nodes carry a box, a leading and a position, and the glyphs
/// are drawn inside a *content box* whose top is
///
/// ```text
/// contentTop = nodeTop + (nodeHeight - leading) / 2
/// ```
///
/// for a centred node, and simply `nodeTop` for a top-anchored one.
///
/// Flutter draws the same content box when the [TextStyle.height] is set
/// to `leading / fontSize`, which is what this widget does.
class FigmaText extends StatelessWidget {
  const FigmaText({
    super.key,
    required this.text,
    required this.left,
    required this.nodeTop,
    required this.nodeHeight,
    required this.fontSize,
    required this.leading,
    required this.style,
    this.width,
    this.maxLines = 1,
    this.anchor = FigmaTextAnchor.center,
    this.textAlign,
  });

  /// The label.
  final String text;

  /// Left edge of the text node.
  final double left;

  /// Top of the text node.
  final double nodeTop;

  /// Height of the text node.
  final double nodeHeight;

  /// Font size of the label.
  final double fontSize;

  /// Leading of the label — Figma's line height.
  final double leading;

  /// The style, minus its size and height, which this widget owns.
  final TextStyle style;

  /// Width available to the label. When null the label may use the space
  /// it needs.
  final double? width;

  /// How many lines the label may use.
  final int maxLines;

  /// How the text is anchored inside its node.
  final FigmaTextAnchor anchor;

  /// How the text is aligned inside its box.
  ///
  /// Figma's right-aligned nodes (the item quantities) are pinned to the
  /// *right* edge of their box, so their glyphs end where the node ends.
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final resolved = style.copyWith(
      fontSize: fontSize,
      height: PaymentGeometry.textHeight(leading: leading, fontSize: fontSize),
      letterSpacing: style.letterSpacing ?? 0,
    );

    final top = switch (anchor) {
      FigmaTextAnchor.top => nodeTop,
      FigmaTextAnchor.center =>
        nodeTop + (nodeHeight - leading) / 2,
    };

    return Positioned(
      left: left,
      top: top - PaymentGeometry.bandBottom,
      width: width,
      child: Text(
        text,
        maxLines: maxLines,
        overflow: maxLines == 1 ? TextOverflow.ellipsis : TextOverflow.clip,
        softWrap: maxLines > 1,
        textAlign: textAlign,
        style: resolved,
      ),
    );
  }
}
