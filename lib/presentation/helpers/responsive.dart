import 'package:flutter/material.dart';

/// ResponsiveFrave — minimal breakpoint helper used by the Leader-owned
/// screens (UC-12). Screens can stay single-column on phones and switch
/// to multi-column on tablets without us having to install a 3rd-party
/// responsive framework.
class ResponsiveFrave {
  ResponsiveFrave._();

  static const double _mobileMax = 600;
  static const double _tabletMax = 1024;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < _mobileMax;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= _mobileMax && w < _tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= _tabletMax;

  static double widthPercent(BuildContext context, double percent) =>
      MediaQuery.of(context).size.width * percent / 100;

  static double heightPercent(BuildContext context, double percent) =>
      MediaQuery.of(context).size.height * percent / 100;

  /// Returns [desktop], [tablet], or [mobile] based on the current
  /// breakpoint. Always falls back to [mobile] when the parent variants
  /// are `null`.
  static Widget adaptive({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    if (isDesktop(context) && desktop != null) return desktop;
    if (isTablet(context) && tablet != null) return tablet;
    return mobile;
  }

  /// Returns the grid crossAxisCount appropriate for the current width.
  static int gridColumns(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    if (isDesktop(context)) return desktop;
    if (isTablet(context)) return tablet;
    return mobile;
  }
}