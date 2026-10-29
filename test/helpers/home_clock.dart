// Deterministic clock for the home screen's time-of-day greeting.
//
// The header greeting ("Chào buổi sáng / chiều / tối") is part of the
// Figma home frame, so it must stay in the UI — but it must not depend on
// the wall clock, or the golden/geometry tests would produce a different
// image every time they run at another hour of the day.
//
// Tests mount [ClientHomeScreen] with this clock instead of the real one.
// The app itself keeps using the real clock, so the greeting is still
// correct for the user.

import 'package:delicia/presentation/client/home/home_screen.dart';

/// A fixed instant used as "now" by the home-screen tests.
///
/// 09:00 lands in the morning bucket, which is also what the home-screen
/// fixture asserts on.
DateTime fixedHomeNow() => DateTime(2024, 1, 15, 9, 0, 0);

/// A [HomeClock] that always returns [fixedHomeNow].
///
/// Declared `const` so it can be passed to a `const ClientHomeScreen`.
const HomeClock fixedHomeClock = fixedHomeNow;
