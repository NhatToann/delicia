// Test helpers for driving the frame clock.
//
// `pumpAndSettle` cannot be used on the admin screens. Those screens
// show a `CircularProgressIndicator` while the catalogue or the order
// feed is still loading, and the spinner schedules frames forever —
// `pumpAndSettle` waits for the frames to stop, so it spins until the
// test times out and the runner reports the test as "did not complete".
//
// Whether the spinner is still on screen when `pumpAndSettle` is
// called depends on a race: the fake services deliver their seed
// through `scheduleMicrotask`, and whether that microtask has already
// run before the first frame is pumped is not deterministic. That is
// why the widget tests were flaky — they passed on some runs and hung
// on others.
//
// [settleAdmin] removes the race entirely: it pumps a fixed number of
// frames, which flushes the pending microtasks, lets the bloc emit and
// finishes the route / menu animations. It can never hang.

import 'package:flutter_test/flutter_test.dart';

/// Pumps [frames] frames of [step] each.
///
/// The default of fourteen frames (700 ms) is enough for the fake
/// services to deliver their seed, for the bloc to emit, for the screen
/// to rebuild and for a route or menu transition to finish.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 14,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Settles the admin screens.
///
/// Frames are pumped instead of waiting for the animations: the
/// loading spinner would keep `pumpAndSettle` spinning forever.
Future<void> settleAdmin(
  WidgetTester tester, {
  int frames = 14,
}) async {
  await pumpFrames(tester, frames: frames);
}

/// Pumps frames until [finder] finds something, or gives up.
///
/// Used when a screen needs more than one round of asynchronous work
/// before the widget under test shows up.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxFrames = 40,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
}
