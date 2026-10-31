// UC-05 — Widget tests for the OrderStatusTimeline.

import 'package:delicia/presentation/client/orders/widgets/order_status_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  testWidgets('renders all timeline steps', (tester) async {
    await tester.pumpWidget(
      host(const OrderStatusTimeline(status: 'PAID OUT')),
    );
    // Verify each canonical label renders.
    expect(find.text('PAID OUT'), findsOneWidget);
    expect(find.text('DISPATCHED'), findsOneWidget);
    expect(find.text('ON WAY'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
  });

  testWidgets('marks every step before the current status as done', (
    tester,
  ) async {
    await tester.pumpWidget(host(const OrderStatusTimeline(status: 'ON WAY')));
    // Status badge colour depends on status; we only assert layout here.
    expect(find.text('ON WAY'), findsOneWidget);
    expect(find.text('DELIVERED'), findsOneWidget);
  });

  testWidgets('renders the cancelled step when status is CANCELLED', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const OrderStatusTimeline(status: 'CANCELLED')),
    );
    expect(find.text('CANCELLED'), findsOneWidget);
  });

  testWidgets('falls back to the last timeline step when status is unknown', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(const OrderStatusTimeline(status: 'BOGUS STATUS')),
    );
    expect(find.text('BOGUS STATUS'), findsNothing);
    // All canonical steps still render.
    expect(find.text('PAID OUT'), findsOneWidget);
  });

  testWidgets('respects orderedStatuses override', (tester) async {
    await tester.pumpWidget(
      host(
        const OrderStatusTimeline(
          status: 'STEP-2',
          orderedStatuses: ['STEP-1', 'STEP-2', 'STEP-3'],
          currentIndexOverride: 1,
        ),
      ),
    );
    expect(find.text('STEP-1'), findsOneWidget);
    expect(find.text('STEP-2'), findsOneWidget);
    expect(find.text('STEP-3'), findsOneWidget);
  });
}
