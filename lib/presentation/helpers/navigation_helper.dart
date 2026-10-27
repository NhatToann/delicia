import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Leaves the current screen, safely.
///
/// `context.pop()` is the normal path, but it **throws** when there is
/// nothing to pop — the screen was opened directly (a deep link, a
/// restored state, or a test that renders it standalone). A back button
/// that throws is a dead button.
///
/// This helper does what a customer expects from a back arrow: go back
/// when there is somewhere to go back to, and otherwise land on a
/// sensible fallback route.
///
/// The fallback defaults to the client home, because that is the root of
/// the client flow. Screens that live in another flow (the delivery map,
/// for instance) pass their own.
void goBack(
  BuildContext context, {
  String fallback = '/client/home',
}) {
  if (!context.mounted) return;

  final router = _routerOf(context);

  // No GoRouter in the tree — a bare `Navigator` (an isolated widget
  // test, or a modal pushed outside the router). Popping the navigator
  // is the best that can be done here.
  if (router == null) {
    final navigator = Navigator.maybeOf(context);
    if (navigator != null && navigator.canPop()) navigator.pop();
    return;
  }

  if (router.canPop()) {
    router.pop();
    return;
  }

  // Nothing to pop — go to the fallback instead of throwing.
  router.go(fallback);
}

/// The nearest GoRouter, or null when the context is not inside one.
///
/// [GoRouter.of] asserts when no router is mounted, which would turn a
/// "nothing to go back to" situation into a crash — exactly what this
/// helper exists to prevent.
GoRouter? _routerOf(BuildContext context) {
  try {
    return GoRouter.of(context);
  } on AssertionError {
    return null;
  } on Error {
    return null;
  }
}
