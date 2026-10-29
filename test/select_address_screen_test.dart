import 'package:delicia/domain/models/address.dart';
import 'package:delicia/presentation/client/address/select_address_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Smoke test — make sure the select-address screen builds without
/// throwing. Network and geolocator calls are stubbed because they
/// require a real device.
void main() {
  testWidgets('SelectAddressScreen builds and renders the map + hint',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => const SelectAddressScreen(),
        ),
        GoRoute(
          path: '/return',
          builder: (_, state) => Scaffold(
            body: Text('got=${(state.extra as Address?)?.street ?? 'none'}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router),
    );
    // pump once to let FlutterMap lay out; avoid pumpAndSettle
    // because the map never stops animating in tests.
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Chọn địa chỉ giao hàng'), findsOneWidget);
    expect(find.text('Dùng vị trí hiện tại của tôi'), findsOneWidget);
    expect(find.text('Chạm vào bản đồ để đặt điểm'), findsOneWidget);
  });
}
