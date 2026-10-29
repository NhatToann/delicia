import 'package:flutter/material.dart';

import 'colors_frave.dart';

/// Typography for the Delicia brand.
///
/// Figma node 47:23 declares a single family — **League Spartan** — used at
/// Light / Regular / Medium / SemiBold / Bold. It ships as a variable font
/// (`assets/fonts/LeagueSpartan.ttf`), so every weight is one family with a
/// different [FontWeight] and nothing is fetched at runtime.
class FraveText {
  const FraveText._();

  static const String family = 'LeagueSpartan';

  static TextStyle _style(
    double size,
    FontWeight weight, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      TextStyle(
        fontFamily: family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle light(
    double size, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      _style(
        size,
        FontWeight.w300,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle regular(
    double size, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      _style(
        size,
        FontWeight.w400,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle medium(
    double size, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      _style(
        size,
        FontWeight.w500,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle semiBold(
    double size, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      _style(
        size,
        FontWeight.w600,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle bold(
    double size, {
    Color color = ColorsFrave.ink,
    double? height = 1.1,
    double? letterSpacing = 0,
  }) =>
      _style(
        size,
        FontWeight.w700,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );
}