// UC-09 — AdminDeliveryUsersScreen widget test.
//
// The screen lists every courier with an on / off switch. The test
// asserts that the rows render and that the switch forwards the
// enable / disable call to the service.

import 'package:delicia/domain/models/delivery_user.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/presentation/admin/delivery/delivery_users_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/pump_helpers.dart';

DeliveryUser _driver({
  required String uid,
  String name = 'Nguyễn Tài xế',
  bool isEnabled = true,
}) {
  return DeliveryUser(
    uid: uid,
    name: name,
    phone: '0900000000',
    isEnabled: isEnabled,
  );
}

/// Mounts the delivery screen with the fake service.
Widget _harness(DeliveryUsersService deliveryUsersService) {
  return RepositoryProvider<DeliveryUsersService>.value(
    value: deliveryUsersService,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminDeliveryUsersScreen(),
    ),
  );
}

void main() {
  testWidgets('renders a row per driver', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService(
      users: <DeliveryUser>[
        _driver(uid: 'd1', name: 'Nguyễn Tài xế'),
        _driver(uid: 'd2', name: 'Trần B', isEnabled: false),
      ],
    );

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    expect(find.text('Quản lý tài xế'), findsOneWidget);
    expect(find.text('Nguyễn Tài xế'), findsOneWidget);
    expect(find.text('Trần B'), findsOneWidget);
    // The enabled / disabled badge.
    expect(find.text('Đang hoạt động'), findsOneWidget);
    expect(find.text('Đã ngừng'), findsOneWidget);
  });

  testWidgets('the switch disables the driver', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService(
      users: <DeliveryUser>[_driver(uid: 'd1')],
    );

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.tap(find.byType(Switch));
    await settleAdmin(tester);

    expect(service.toggles.length, 1);
    expect(service.toggles.first['uid'], 'd1');
    expect(service.toggles.first['enabled'], isFalse);
  });

  testWidgets('the search field filters the rows', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService(
      users: <DeliveryUser>[
        _driver(uid: 'd1', name: 'Nguyễn Tài xế'),
        _driver(uid: 'd2', name: 'Trần B'),
      ],
    );

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.enterText(find.byType(TextField).first, 'trần');
    await settleAdmin(tester);

    expect(find.text('Nguyễn Tài xế'), findsNothing);
    expect(find.text('Trần B'), findsOneWidget);
  });

  testWidgets('shows the empty state when there is no driver', (
    WidgetTester tester,
  ) async {
    final service = FakeDeliveryUsersService();

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    expect(find.text('Chưa có tài xế nào'), findsOneWidget);
  });

  testWidgets('the delete button asks for a confirmation', (
    WidgetTester tester,
  ) async {
    final service = FakeDeliveryUsersService(
      users: <DeliveryUser>[_driver(uid: 'd1')],
    );

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settleAdmin(tester);

    expect(find.text('Xoá tài xế?'), findsOneWidget);
    expect(service.deleted, isEmpty);
  });

  testWidgets('deletes the driver after the confirmation', (
    WidgetTester tester,
  ) async {
    final service = FakeDeliveryUsersService(
      users: <DeliveryUser>[_driver(uid: 'd1')],
    );

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await settleAdmin(tester);

    // The dialog has a "Xoá" action next to the "Huỷ" one.
    await tester.tap(find.widgetWithText(TextButton, 'Xoá'));
    await settleAdmin(tester);

    expect(service.deleted.length, 1);
    expect(service.deleted.first['uid'], 'd1');
  });
}
