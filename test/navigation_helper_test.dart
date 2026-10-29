/// Guards the safe back-navigation contract (Task 4).
///
/// A back arrow that throws is a dead arrow. `context.pop()` throws when
/// there is nothing to pop — which is exactly what happens when a screen
/// is opened directly (a deep link, a restored state, or a widget test
/// that renders the screen standalone).
///
/// [goBack] is the single place that decides what "back" means:
///
///   * something to go back to  → pop;
///   * nothing to go back to    → go to a sensible fallback route
///     (`/client/home` by default, `/delivery/home` for the delivery map,
///     `/intro` or `/login` for the auth screens);
///   * no GoRouter in the tree → pop the plain Navigator, if it can.
library;

import 'package:delicia/presentation/helpers/navigation_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  group('goBack', () {
    testWidgets('pops when there is somewhere to go back to',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/first',
        routes: <RouteBase>[
          GoRoute(path: '/first', builder: (_, _) => const _Screen()),
          GoRoute(path: '/second', builder: (_, _) => const _Screen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      router.push('/second');
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_Screen).last);
      goBack(context);
      await tester.pumpAndSettle();

      expect(_locationOf(router), '/first');
    });

    testWidgets('falls back to the home route when there is nothing to pop',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/client/orders',
        routes: <RouteBase>[
          GoRoute(path: '/client/orders', builder: (_, _) => const _Screen()),
          GoRoute(path: '/client/home', builder: (_, _) => const _Screen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      // The router was opened straight at the screen, so there is nothing
      // to pop — the helper must not throw.
      final context = tester.element(find.byType(_Screen).last);
      expect(() => goBack(context), returnsNormally);
      await tester.pumpAndSettle();

      expect(_locationOf(router), '/client/home');
    });

    testWidgets('honours a custom fallback route',
        (WidgetTester tester) async {
      final router = GoRouter(
        initialLocation: '/delivery/map/42',
        routes: <RouteBase>[
          GoRoute(path: '/delivery/map/:id', builder: (_, _) => const _Screen()),
          GoRoute(path: '/delivery/home', builder: (_, _) => const _Screen()),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_Screen).last);
      goBack(context, fallback: '/delivery/home');
      await tester.pumpAndSettle();

      expect(_locationOf(router), '/delivery/home');
    });

    testWidgets('does not throw outside a GoRouter tree',
        (WidgetTester tester) async {
      // A widget test that renders a screen standalone has no router —
      // `GoRouter.of` would assert, which is exactly the crash the
      // helper is meant to prevent.
      await tester.pumpWidget(
        const MaterialApp(home: _Screen()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_Screen));
      expect(() => goBack(context), returnsNormally);
    });

    testWidgets('does not throw after the screen is unmounted',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: _Screen()),
      );
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(_Screen));
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      // The context is gone — the helper must not touch it.
      expect(() => goBack(context), returnsNormally);
    });
  });
}

class _Screen extends StatelessWidget {
  const _Screen();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('screen')));
}

/// The router's current location.
///
/// go_router 14 exposes the location through the delegate's current
/// configuration rather than a `location` getter.
String _locationOf(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.toString();
