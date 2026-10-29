/// The geometry of the Figma product-detail frame (node `192:1216`).
///
/// The frame is 393 x 852. Every constant below is a **frame** coordinate,
/// i.e. the position the element has on the 393 x 852 screen:
///
///   yellow band      y0..129
///   back chevron     x30 y79   8 x 13
///   title            x57 y79
///   heart button     x337 y79  21 x 21
///   sheet top        y129      30 px rounded corners
///   photo            x35 y162  323 x 220, radius 20
///   price row        x35 y411
///   stepper discs    x276 / x338, 22 x 22
///   title            x36 y462
///   description      x36 y486
///   size list        x35 y552
///   radio buttons    x341..355
///   CTA              x103 y726  180 x 33
///   footer           y791..852  61 tall
///
/// Keeping the numbers in one place means the layout can be re-tuned
/// against the design without hunting through the widgets, and the
/// geometry tests can assert against the same source of truth.
class ProductDetailGeometry {
  const ProductDetailGeometry._();

  /// Horizontal inset of the sheet's content (Figma x35 / x36).
  static const double pageInset = 35;

  /// Top of the header band — below the status bar.
  ///
  /// The Figma frame shows the OS status bar at y12..24 and the back
  /// chevron at y79, so the app leaves the safe area alone and places
  /// the header below it.
  ///
  /// The value is the *extra* space the header adds on top of the
  /// system's safe-area inset, so on a phone with a notch or a status
  /// bar the header sits below the notification shade instead of under
  /// it. Before this was applied the yellow band was painted from y0
  /// and the status bar icons overlapped the back button.
  static const double headerTop = 16;

  /// Minimum gap between the status bar and the back chevron.
  ///
  /// A device with a tall status bar (dual punch-hole, 3-button, or a
  /// large font scale) needs more room than the Figma frame shows, so
  /// the effective inset is `max(systemInset, headerTop)`.
  static const double minHeaderTop = 16;

  /// Left edge of the back chevron (Figma x30).
  static const double backButtonLeft = 30;

  /// Width of the back chevron glyph (Figma 8).
  static const double backButtonWidth = 8;

  /// Height of the back chevron glyph (Figma 13).
  static const double backButtonHeight = 13;

  /// The tappable box around the back chevron.
  ///
  /// The glyph itself is only 8 x 13 px, which is far below the 48 px
  /// minimum touch target Android and iOS recommend. The button is
  /// therefore padded out to a 44 x 44 box — centred on the glyph, so
  /// the arrow still appears exactly where Figma drew it.
  static const double backButtonHitSize = 44;

  /// Size of the heart button (Figma 21 x 21).
  static const double heartSize = 21;

  /// The tappable box around the heart glyph.
  static const double heartHitSize = 40;

  /// Gap between the photo and the top of the sheet.
  ///
  /// The sheet starts at y129 and the photo at y162, so the photo sits
  /// 33 px below the sheet's top edge.
  static const double photoTopInset = 33;

  /// Corner radius of the photo (Figma 20).
  static const double photoRadius = 20;

  /// Width / height of the photo (Figma 323 x 220).
  static const double photoWidth = 323;

  /// Height of the photo (Figma 220).
  static const double photoHeight = 220;

  /// Aspect ratio of the photo — 323 / 220.
  static const double photoAspect = photoWidth / photoHeight;

  /// Gap between the photo and the price row.
  static const double priceGap = 26;

  /// Gap between the price row and the dish name.
  static const double titleGap = 24;

  /// Gap between the dish name and its description.
  static const double descriptionGap = 8;

  /// Gap between the description and the size section.
  static const double sizeGap = 26;

  /// Gap between the size list and the CTA.
  static const double ctaGap = 24;

  /// Space below the CTA before the sheet ends.
  static const double ctaBottomGap = 28;

  /// Diameter of the two stepper discs (Figma 22).
  static const double stepperSize = 22;

  /// Height of the orange "Add to Cart" pill (Figma 33).
  static const double ctaHeight = 44;

  /// Horizontal inset of the CTA (Figma x103, so 103 px on each side).
  ///
  /// Figma's frame is 393 px wide, which leaves a 187 px pill. On a
  /// narrower phone that inset would squeeze the label out of the
  /// button, so the inset is capped and the pill is allowed to grow —
  /// see `ctaInsetFor`.
  static const double ctaInset = 103;

  /// The narrowest the CTA may be allowed to get.
  ///
  /// 44 px is the minimum comfortable touch target, so the pill is
  /// never squeezed below 193 px wide on a 393 px screen.
  static const double minCtaWidth = 193;

  /// The horizontal inset of the CTA on a screen [width] px wide.
  ///
  /// It is the Figma inset, but never so much that the pill would be
  /// narrower than [minCtaWidth]. This keeps the "Add to Cart" label
  /// and the line total on one line on small phones.
  static double ctaInsetFor(double width) {
    final inset = (width - minCtaWidth) / 2;
    return inset < ctaInset ? inset : ctaInset;
  }

  /// Height of the orange footer bar (Figma 61).
  static const double footerHeight = 61;
}
