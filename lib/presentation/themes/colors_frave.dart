import 'package:flutter/material.dart';

/// Delicia brand palette.
///
/// Colours are sampled directly from the UI kit mockups so the app matches
/// the design 1:1:
///
/// Launch First Screen — `0 - A - Launch First Screen.png`
///   background #F5CB58 · accent #FF642F
///
/// Launch Welcome Screen — `0 - B - Launch Welcome Screen.png`
///   background #E95322 · accent #F5CB58 · secondary pill #F3E9B5
///
/// Auth screens (2-A, 2-B, 2-C) — soft variants derived from the brand
/// palette (~10% softer than the originals; see [ColorsFrave.authBg]).
class ColorsFrave {
  // ---- Launch First Screen (yellow background) -------------------------
  /// Full-screen yellow of the Launch First screen.
  static const Color launchBg = Color(0xFFF5CB58);

  /// Orange used for the mark and the round CTA on Launch First.
  static const Color launchAccent = Color(0xFFFF642F);

  // ---- Launch Welcome Screen (orange background) -----------------------
  /// Full-screen orange of the Launch Welcome screen.
  static const Color welcomeBg = Color(0xFFE95322);

  /// Yellow headline / button fill on the orange Welcome screen.
  static const Color welcomeAccent = Color(0xFFF5CB58);

  /// Cream secondary pill on the orange Welcome screen.
  static const Color welcomeSecondary = Color(0xFFF3E9B5);

  /// Body copy on the Welcome screen.
  static const Color welcomeOnBg = Color(0xFFF8F8F8);

  // ---- Auth palette (derived: ~10% softer than the originals) ---------
  // The UI kit uses a light grey backdrop (#F5F5F5) and a deep brown ink
  // (#391713) on the auth screens. We soften both by 10% toward #F8F8F8
  // (bg) and blend the deep ink toward a warmer grey for body copy, while
  // keeping the deep orange/yellow accents slightly muted so the brand
  // colour reads as warm but never overpowering on forms.
  static const Color authBg = Color(0xFFF8F5F0);          // was #F5F5F5
  static const Color authInk = Color(0xFF45352D);          // was #391713
  static const Color authInkSoft = Color(0xFF7B6960);      // was #6B5E57
  static const Color authAccent = Color(0xFFD74E1E);       // was #E95322 (-10%)
  static const Color authAccentYellow = Color(0xFFE5BC4F); // was #F5CB58 (-10%)
  static const Color authInputBorder = Color(0xFF45352D);  // dark brown border

  // ---- Primary (warm orange, food-app appeal) --------------------------
  static const Color primaryColor = Color(0xFFD74E1E);     // authAccent
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFFFE0D6);
  static const Color onPrimaryContainer = Color(0xFF2D0E00);

  /// Bright orange used for accents on light surfaces.
  static const Color primaryBright = Color(0xFFFF642F);

  // ---- Secondary (fresh green) -----------------------------------------
  static const Color secondaryColor = Color(0xFF2EC4B6);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color secondaryContainer = Color(0xFFD0F5F0);
  static const Color onSecondaryContainer = Color(0xFF002420);

  // ---- Tertiary (deep blue) --------------------------------------------
  static const Color tertiaryColor = Color(0xFF4A6FA5);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color tertiaryContainer = Color(0xFFD6E3FF);
  static const Color onTertiaryContainer = Color(0xFF001C3A);

  // ---- Home screen (Figma node 47:23, style variables) ------------------
  // Taken verbatim from the Figma style set of node 47:23:
  //   Font #391713 · Font 2 #F8F8F8 · Orange Base #E95322
  //   Yellow Base #F5CB58 · Yellow 2 #F3E9B5
  /// Full-bleed header band behind the search row.
  static const Color headerYellow = Color(0xFFF5CB58);

  /// Soft yellow used for the category pills.
  static const Color pillYellow = Color(0xFFF3E9B5);

  /// Deep brown ink used for all headings and labels.
  static const Color ink = Color(0xFF391713);

  /// Near-white used for text on orange fills.
  static const Color onOrange = Color(0xFFF8F8F8);

  /// Page background for the My Orders screen (Figma node 147:2106 /
  /// 147:2153 use "Font 2" #F8F8F8 as the content fill, not the kit's
  /// grey #F5F5F5).
  static const Color pageBg = Color(0xFFF8F8F8);

  /// Content background of the scroll body.
  static const Color contentBg = Color(0xFFF5F5F5);

  /// Bottom navigation fill and price chips.
  static const Color navOrange = Color(0xFFE95322);

  /// Lighter orange used for the active tab icon inside the nav bar.
  static const Color navActive = Color(0xFFF29E82);

  /// "Orange 2" from the Figma style set (#FFDECF). Used for the
  /// inactive filter chips and the secondary action buttons on the
  /// My Orders screen (Figma nodes 147:2106 / 147:2153).
  static const Color orangeSoft = Color(0xFFFFDECF);

  /// Hairline divider colour used between order rows (#FFD8C7).
  static const Color dividerOrange = Color(0xFFFFD8C7);

  // ---- Surface & background --------------------------------------------
  static const Color backgroundColor = Color(0xFFF5F5F5);   // kit content bg
  static const Color surfaceColor = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1ECE6);
  static const Color onSurface = Color(0xFF2A2522);
  static const Color onSurfaceVariant = Color(0xFF5F514A);

  // ---- Text --------------------------------------------------------------
  static const Color darkText = Color(0xFF25201E);
  static const Color greyText = Color(0xFF7B6960);
  static const Color lightGrey = Color(0xFFB8ACA5);

  // ---- Utility -----------------------------------------------------------
  static const Color white = Colors.white;
  static const Color black = Colors.black;
  static const Color errorColor = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color successColor = Color(0xFF2E7D32);
  static const Color warningColor = Color(0xFFE65100);

  // ---- Outline & dividers ------------------------------------------------
  static const Color outline = Color(0xFF7B6E68);
  static const Color outlineVariant = Color(0xFFE2D7D0);

  // ---- Elevation ----------------------------------------------------------
  static const Color surfaceTint = primaryColor;

  // ---- Gradient -----------------------------------------------------------
  static const List<Color> primaryGradient = <Color>[
    Color(0xFFE0571F),
    Color(0xFFF08F65),
  ];
}

/// Shared corner radii so every screen curves the same way.
class RadiusFrave {
  static const double button = 26;
  static const double field = 18;     // pill-shaped input — matches 2A
  static const double card = 20;
  static const double sheet = 28;
}