// UC-09 — AdminDriverFormScreen widget test.
//
// The screen creates a delivery driver: name, phone, email and password.
// The test asserts the validation and that the form forwards the data to
// the service.

import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/presentation/admin/delivery/driver_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';
import 'helpers/pump_helpers.dart';

/// Mounts the driver form with the fake service.
Widget _harness(DeliveryUsersService deliveryUsersService) {
  return RepositoryProvider<DeliveryUsersService>.value(
    value: deliveryUsersService,
    child: const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AdminDriverFormScreen(),
    ),
  );
}

void main() {
  testWidgets('renders the driver form', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService();

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    expect(find.text('Thêm tài xế mới'), findsOneWidget);
    expect(find.text('Họ và tên'), findsOneWidget);
    expect(find.text('Số điện thoại'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Mật khẩu'), findsOneWidget);
  });

  testWidgets('refuses to save an empty form', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService();

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.tap(find.text('Thêm tài xế'));
    await settleAdmin(tester);

    expect(service.created, isEmpty);
    expect(find.text('Vui lòng nhập họ và tên tài xế'), findsOneWidget);
    expect(find.text('Vui lòng nhập email'), findsOneWidget);
  });

  testWidgets('refuses an invalid email', (WidgetTester tester) async {
    final service = FakeDeliveryUsersService();

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Tài xế');
    await tester.enterText(find.byType(TextFormField).at(1), '0900000000');
    await tester.enterText(find.byType(TextFormField).at(2), 'khong-hop-le');
    await tester.enterText(find.byType(TextFormField).at(3), '123456');
    await settleAdmin(tester);

    await tester.tap(find.text('Thêm tài xế'));
    await settleAdmin(tester);

    expect(service.created, isEmpty);
    expect(find.text('Email không hợp lệ'), findsOneWidget);
  });

  testWidgets('sends the new driver to the service', (
    WidgetTester tester,
  ) async {
    final service = FakeDeliveryUsersService();

    await tester.pumpWidget(_harness(service));
    await settleAdmin(tester);

    await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Tài xế');
    await tester.enterText(find.byType(TextFormField).at(1), '0900000000');
    await tester.enterText(
      find.byType(TextFormField).at(2),
      'tai.xe@delicia.vn',
    );
    await tester.enterText(find.byType(TextFormField).at(3), '123456');
    await settleAdmin(tester);

    await tester.tap(find.text('Thêm tài xế'));
    await settleAdmin(tester);

    expect(service.created.length, 1);
    final created = service.created.first;
    expect(created['email'], 'tai.xe@delicia.vn');
    expect(created['firstName'], 'Nguyễn');
    expect(created['lastName'], 'Tài xế');
    expect(created['phone'], '0900000000');
  });
}
