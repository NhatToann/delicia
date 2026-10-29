import 'package:flutter/material.dart';

/// The Figma geometry of the Payment screen (node `202:2956`).
///
/// The frame is 393 x 852 and Figma pins every element to an exact
/// coordinate on it, so the screen reproduces those coordinates literally
/// instead of approximating them with a gap-based column.
///
/// Every number in this class comes from the Figma node tree of
/// `202:2956` (or from the node it references), so it can be checked
/// against the design at any time.
///
/// ## The two conversions
///
/// **The yellow band.** Figma's "Principal Page" layer is a yellow rounded
/// rect with a white sheet laid over it; the sheet's flat top edge lands at
/// y132 and its top corners are rounded by 30 px. The Flutter screen is
/// split into a yellow header ([bandBottom] tall) and a white sheet below
/// it, so every Figma `y` inside the sheet is shifted up by [bandBottom].
///
/// **The right margin.** Figma's right edge is x358, i.e. 35 px from the
/// frame's right edge. On a wider phone that margin is kept so the design's
/// proportions hold; on a narrower one it shrinks proportionally.
///
/// ## How Figma positions text
///
/// Every label in the frame is a text node with a box and a *leading*. There
/// are two kinds, and they behave differently:
///
///  * A plain paragraph (`<p>` in the Figma export) has `nodeHeight ==
///    leading`, so its content box starts exactly at `nodeTop`.
///  * A centred flex column (`flex flex-col justify-center`) has a short
///    box and a taller content box, so the content overflows
///    symmetrically — which is why "Order Summary" is drawn at y291 even
///    though its node starts at y293.
///
/// Flutter draws the same content box when the [TextStyle.height] is set
/// to `leading / fontSize`, so [textTop] and [textHeight] reproduce the
/// design exactly.
class PaymentGeometry {
  const PaymentGeometry._();

  /// Width of the Figma frame the coordinates come from.
  static const double designWidth = 393;

  /// Height of the Figma frame.
  static const double designHeight = 852;

  /// Bottom edge of the yellow band; the white sheet starts here.
  static const double bandBottom = 132;

  /// Right margin of the content — Figma's right edge is x358.
  static const double rightMargin = 35;

  /// Distance between two item rows in the Order Summary block.
  static const double itemPitch = 16;

  /// Radius of the white sheet's top corners.
  static const double sheetRadius = 30;

  /// League Spartan's line height as a multiple of the font size.
  ///
  /// The font's ascent is 1400 and its descent 440 units on a 2000 unit em
  /// with no line gap, so a "normal" leading is (1400 + 440) / 2000 = 0.92.
  static const double normalLeading = 0.92;

  // ---- Header -------------------------------------------------------------

  /// Top of the "Payment" title node (Figma node `202:2968`).
  static const double titleTop = 73;

  /// Height of the "Payment" title node.
  static const double titleNodeHeight = 26;

  /// Font size of the "Payment" title (Figma's "titulo screen" token).
  static const double titleSize = 28;

  /// Leading of the "Payment" title.
  ///
  /// Figma's node box is 26 px tall while the title is a 28 px label, so the
  /// line box is a touch shorter than the type — which is what puts the
  /// glyphs at y74..98 in the Figma PNG.
  static const double titleLeading = 26;

  /// Left edge of the back arrow (Figma node `202:2969`, 8 x 13).
  static const double backArrowLeft = 35;

  /// Top of the back arrow.
  static const double backArrowTop = 81;

  // ---- Shipping address ---------------------------------------------------

  /// Left edge of the "Shipping Address" title node (`202:2972`).
  static const double addressTitleLeft = 46;

  /// Top of the "Shipping Address" title node.
  static const double addressTitleTop = 172;

  /// Height of the "Shipping Address" title node.
  static const double addressTitleNodeHeight = 14;

  /// Font size of the "Shipping Address" title (Figma's "Title" token).
  static const double addressTitleSize = 24;

  /// Leading of the "Shipping Address" title (Figma's "Title" token).
  static const double addressTitleLeading = 26;

  /// Left edge of the write icon's *bleeding* artwork (`202:2995`).
  ///
  /// Figma gives the icon a 10 x 10.713 node and lets the artwork overflow
  /// it by 4.91 % horizontally and 4.58 % vertically, so the exported SVG
  /// is 10.9819 x 11.6952 and starts 0.49 px left of and 0.49 px above
  /// the node.
  static const double writeIconLeft = 238.51;

  /// Top of the write icon's bleeding artwork.
  static const double writeIconTop = 174.51;

  /// Width of the write icon artwork.
  static const double writeIconWidth = 10.9819;

  /// Height of the write icon artwork.
  static const double writeIconHeight = 11.6952;

  /// Left edge of the cream address card (`202:2971`).
  static const double addressCardLeft = 35;

  /// Top of the cream address card.
  static const double addressCardTop = 209;

  /// Width of the cream address card.
  static const double addressCardWidth = 323;

  /// Height of the cream address card.
  static const double addressCardHeight = 35;

  /// Radius of the cream address card.
  static const double addressCardRadius = 20;

  /// Left edge of the address text node (`202:2974`).
  static const double addressTextLeft = 48;

  /// Top of the address text node.
  static const double addressTextTop = 221;

  /// Height of the address text node.
  static const double addressTextNodeHeight = 14;

  /// Font size of the address text.
  static const double addressTextSize = 16;

  /// Leading of the address text.
  ///
  /// Figma's "Paragraph" token for the 16 px address uses the font's own
  /// metrics — (1400 + 440) / 2000 = 0.92 em — so the line box is 14.72 px.
  static const double addressTextLeading = addressTextSize * normalLeading;

  // ---- Order summary ------------------------------------------------------

  /// Left edge of the "Order Summary" title node (`202:2973`).
  static const double summaryTitleLeft = 35;

  /// Top of the "Order Summary" title node.
  static const double summaryTitleTop = 293;

  /// Height of the "Order Summary" title node.
  static const double summaryTitleNodeHeight = 14;

  /// Font size of the "Order Summary" / "Payment Method" / "Delivery Time"
  /// titles (Figma's "subtitulo" token).
  static const double sectionTitleSize = 20;

  /// Leading of the section titles — Figma's "subtitulo" token has
  /// `lineHeight: 100`, i.e. the font's own metrics.
  static const double sectionTitleLeading = sectionTitleSize * normalLeading;

  /// Left edge of the item rows (`202:3409`).
  static const double itemLeft = 35;

  /// Top of the first item row.
  static const double firstItemTop = 322;

  /// Left edge of the item quantity column.
  ///
  /// Figma's two quantity nodes — "2 items" (`202:3126`, x149 w41) and
  /// "1 items" (`202:3412`, x152 w38) — both end at x190, so the column
  /// is right-aligned.
  static const double itemQtyLeft = 149;

  /// Right edge of the item quantity column.
  static const double itemQtyRight = 190;

  /// Width reserved for the item quantity.
  ///
  /// Figma's quantity nodes are 41 px wide ("2 items", `202:3126`) and
  /// 38 px wide ("1 items", `202:3412`); both are right-aligned so the
  /// glyphs end on x189.
  static const double itemQtyWidth = 41;

  /// Left edge of the first quantity node (`202:3126`).
  static const double itemQty1Left = 149;

  /// Left edge of the second quantity node (`202:3412`).
  static const double itemQty2Left = 152;

  /// Font size of the item name and quantity.
  static const double itemFontSize = 14;

  /// Leading of the item name and quantity.
  static const double itemLeading = 14;

  /// How far the price sits below the item name.
  ///
  /// Figma draws "$40.00" at y328 while the name is at y322 — the price is
  /// a 20 px label whose own line box is taller, so it hangs 6 px lower.
  static const double itemPriceDrop = 6;

  /// Font size of the item price (`202:3413`).
  static const double itemPriceSize = 20;

  /// Left edge of the item price.
  static const double itemPriceLeft = 295;

  /// Width reserved for the item price.
  ///
  /// Figma's "$40.00" node (`202:3413`) is 63 px wide and ends at x358,
  /// the content's right margin.
  static const double itemPriceWidth = 63;

  /// Top of the first divider node (`202:2983`).
  static const double divider1Top = 371;

  /// Left edge of the first divider (Figma draws it 1 px further left).
  static const double divider1Left = 34;

  // ---- Payment method -----------------------------------------------------

  /// Left edge of the "Payment Method" title node (`202:3471`).
  static const double methodTitleLeft = 35;

  /// Top of the "Payment Method" title node.
  static const double methodTitleTop = 399;

  /// Height of the "Payment Method" title node.
  static const double methodTitleNodeHeight = 14;

  /// Left edge of the method glyph's node (`286:1862`, 31 x 21.215).
  static const double methodIconLeft = 35;

  /// Top of the method glyph's node.
  static const double methodIconTop = 426;

  /// Width of the method glyph's node.
  static const double methodIconWidth = 31;

  /// Height of the method glyph's node.
  static const double methodIconHeight = 21.2146;

  /// Left edge of the method glyph's *bleeding* artwork.
  ///
  /// Figma lets the card icon overflow its node by 3.61 % horizontally and
  /// 5.28 % vertically, so the artwork is 33.2392 x 23.4538 and starts
  /// 1.12 px left of and 1.12 px above the node.
  static const double methodIconArtLeft = 33.88;

  /// Top of the method glyph's bleeding artwork.
  static const double methodIconArtTop = 424.88;

  /// Width of the method glyph artwork.
  static const double methodIconArtWidth = 33.2392;

  /// Height of the method glyph artwork.
  static const double methodIconArtHeight = 23.4538;

  /// Left edge of the method name node (`202:3480`).
  static const double methodNameLeft = 75;

  /// Top of the method name node.
  static const double methodNameTop = 431;

  /// Height of the method name node.
  static const double methodNameNodeHeight = 14;

  /// Font size of the method name and of the descriptor in the pill.
  static const double methodFontSize = 14;

  /// Leading of the method name and of the descriptor in the pill.
  static const double methodLeading = 14;

  /// Left edge of the cream descriptor pill (`202:3482`).
  static const double methodPillLeft = 200;

  /// Top of the cream descriptor pill.
  static const double methodPillTop = 426;

  /// Width of the cream descriptor pill.
  static const double methodPillWidth = 157;

  /// Height of the cream descriptor pill.
  static const double methodPillHeight = 17.0124;

  /// Radius of the cream descriptor pill.
  static const double methodPillRadius = 9.721;

  /// Left edge of the descriptor text node (`202:3483`).
  static const double methodPillTextLeft = 210;

  /// Top of the descriptor text node.
  static const double methodPillTextTop = 430;

  /// Height of the descriptor text node.
  static const double methodPillTextNodeHeight = 14;

  /// Top of the second divider node (`202:2984`).
  static const double divider2Top = 471;

  // ---- Delivery time ------------------------------------------------------

  /// Left edge of the "Delivery Time" title node (`202:3488`).
  static const double deliveryTitleLeft = 35;

  /// Top of the "Delivery Time" title node.
  static const double deliveryTitleTop = 501;

  /// Height of the "Delivery Time" title node.
  static const double deliveryTitleNodeHeight = 14;

  /// Top of the "Estimated Delivery" caption node (`202:3493`).
  static const double deliveryCaptionTop = 531;

  /// Left edge of the "Estimated Delivery" caption node.
  static const double deliveryCaptionLeft = 35;

  /// Height of the "Estimated Delivery" caption node.
  static const double deliveryCaptionNodeHeight = 14;

  /// Font size of the "Estimated Delivery" caption.
  static const double deliveryCaptionSize = 14;

  /// Top of the "25 mins" value node (`202:3494`).
  static const double deliveryValueTop = 529;

  /// Left edge of the "25 mins" value node.
  static const double deliveryValueLeft = 292;

  /// Width reserved for the "25 mins" value.
  ///
  /// Figma's node (`202:3494`) is 66 px wide and ends at x358.
  static const double deliveryValueWidth = 66;

  /// Height of the "25 mins" value node.
  static const double deliveryValueNodeHeight = 18;

  /// Font size of the "25 mins" value.
  static const double deliveryValueSize = 20;

  /// Top of the third divider node (`202:3495`).
  static const double divider3Top = 582;

  // ---- Total (the one element Figma leaves out) ---------------------------

  /// Top of the Total row.
  ///
  /// Figma draws the third divider at y582 and then leaves 135 px of empty
  /// sheet before the CTA — the slot a total belongs in.
  static const double totalTop = 598;

  /// Height of the Total row.
  static const double totalNodeHeight = 18;

  // ---- CTA ----------------------------------------------------------------

  /// Left edge of the "Pay Now" pill (`202:3509`).
  static const double payNowLeft = 123.2856;

  /// Top of the "Pay Now" pill.
  static const double payNowTop = 717;

  /// Width of the "Pay Now" pill.
  static const double payNowWidth = 157.4286;

  /// Height of the "Pay Now" pill.
  static const double payNowHeight = 38;

  /// Horizontal offset of the pill's centre from the frame's centre.
  ///
  /// Figma places the pill at `left: calc(50% + 5.5px)`, so it sits 5.5 px
  /// to the right of the frame's centre line.
  static const double payNowCentreOffset = 5.5;

  /// Font size of the "Pay Now" label.
  static const double payNowLabelSize = 23.07;

  /// Leading of the "Pay Now" label.
  static const double payNowLabelLeading = 27.143;

  /// Letter spacing of the "Pay Now" label.
  static const double payNowLabelTracking = -0.1154;

  /// Distance from the bottom of the content area to the bottom of the pill.
  ///
  /// Figma's own footer is 61 px tall, so the gap is measured from a
  /// content area that ends at y791. The app-wide navigation bar is
  /// 64 px tall — 3 px more — which would push the pill up by 3 px and
  /// off its Figma baseline. [payNowBottomGapFor] compensates for that
  /// so the button still lands on y717 whichever bar is in use.
  static const double payNowBottomGap = 36;

  /// Height of the Figma footer (node `54:193`).
  static const double figmaFooterHeight = 61;

  /// Height of the app-wide navigation bar.
  static const double navBarHeight = 64;

  /// The gap the "Pay Now" pill needs so it lands on its Figma baseline.
  ///
  /// `payNowBottomGap` is measured from the bottom of Figma's 61 px
  /// footer. With the 64 px navigation bar the content area ends 3 px
  /// lower, so the gap shrinks by the same amount and the pill does not
  /// move.
  static double payNowBottomGapFor(double footerHeight) =>
      payNowBottomGap - (footerHeight - figmaFooterHeight);

  // ---- Edit chip ----------------------------------------------------------

  /// Left edge of the "Edit" chip (`286:1856` / `286:1860`).
  static const double editChipLeft = 300;

  /// Top of the "Edit" chip next to the Order Summary title.
  static const double editChipTop = 293;

  /// Width of the "Edit" chip.
  static const double editChipWidth = 58;

  /// Height of the "Edit" chip.
  static const double editChipHeight = 14;

  /// Font size of the "Edit" label.
  ///
  /// The chip is a 58 x 14 component whose label Figma renders at 12 px
  /// with a `-0.06` tracking — the frame's exported CSS reports a smaller
  /// size, but the design's own raster shows an 18 px wide, 9 px tall word,
  /// which only the 12 px label produces.
  static const double editChipFontSize = 12;

  /// Leading of the "Edit" label — Figma's 10 px line box.
  static const double editChipLeading = 10;

  /// Letter spacing of the "Edit" label.
  static const double editChipTracking = -0.06;

  // ---- Derived ------------------------------------------------------------

  /// The right margin adapted to the real screen width.
  ///
  /// On the 393 px Figma frame the margin is exactly 35 px. On a narrower
  /// phone it shrinks proportionally so the content never overflows; on a
  /// wider one it stays at 35 px so the design's proportions hold.
  static double rightMarginOf(double width) => width >= designWidth
      ? rightMargin
      : width * rightMargin / designWidth;

  /// The left edge of an element that hangs off the right margin.
  ///
  /// [distance] is the element's width and [inset] how far it stops short
  /// of the right margin.
  static double rightEdge(
    double width,
    double distance, {
    double inset = 0,
  }) =>
      width - rightMarginOf(width) - inset - distance;

  /// The top of a text node's content box.
  ///
  /// Figma centres the text's content box inside the node's box, so a
  /// node that is shorter than its leading overflows symmetrically.
  static double textTop({
    required double nodeTop,
    required double nodeHeight,
    required double leading,
  }) =>
      nodeTop + (nodeHeight - leading) / 2;

  /// The `height` a [TextStyle] needs to reproduce Figma's leading.
  ///
  /// Flutter multiplies the font size by `height` to get the line box, so
  /// `leading / fontSize` gives Figma's exact line height.
  static double textHeight({
    required double leading,
    required double fontSize,
  }) =>
      leading / fontSize;
}
