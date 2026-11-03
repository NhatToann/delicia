import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:delicia/presentation/delivery/profile/delivery_profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  User? updatedUser;

  @override
  Future<User> updateProfile({
    required User user,
    required String firstName,
    required String lastName,
    required String phone,
    required String dateOfBirth,
    dynamic profileImageBytes,
    String? profileImageContentType,
  }) async {
    updatedUser = user.copyWith(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      dateOfBirth: dateOfBirth,
    );
    return updatedUser!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeAuthService fakeAuthService;
  late AuthBloc authBloc;

  setUp(() {
    fakeAuthService = _FakeAuthService();
    authBloc = AuthBloc(authService: fakeAuthService);
    authBloc.emit(const AuthState(
      user: User(
        uid: 'driver-test-123',
        email: 'driver.huy@delicia.com',
        firstName: 'Quan',
        lastName: 'Huy',
        phone: '0901234567',
        dateOfBirth: '1995-05-15',
        rolId: 3,
      ),
    ));
  });

  Widget buildTestWidget({bool standalone = true}) {
    return BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: MaterialApp(
        home: standalone
            ? const DeliveryProfileScreen()
            : const Scaffold(body: DeliveryProfileContent()),
      ),
    );
  }

  testWidgets('DeliveryProfileScreen renders all profile fields matching client profile layout', (tester) async {
    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Verify Title & Header
    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

    // Verify fields populated with user data
    expect(find.text('Quan Huy'), findsOneWidget);
    expect(find.text('driver.huy@delicia.com'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('15 / 05 / 1995'), findsOneWidget);
    expect(find.text('Tài xế giao hàng (Driver)'), findsOneWidget);

    // Verify buttons
    expect(find.text('Cập nhật hồ sơ'), findsOneWidget);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
  });

  testWidgets('DeliveryProfileScreen dispatches UpdateProfileEvent on valid form submit', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestWidget());
    await tester.pumpAndSettle();

    // Change full name
    final nameFieldFinder = find.widgetWithText(TextField, 'Quan Huy');
    expect(nameFieldFinder, findsOneWidget);

    await tester.enterText(nameFieldFinder, 'Nguyen Quan Huy');
    await tester.pumpAndSettle();

    // Tap "Cập nhật hồ sơ"
    final updateButtonFinder = find.text('Cập nhật hồ sơ');
    await tester.runAsync(() async {
      await tester.tap(updateButtonFinder);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();

    // Verify updated user in AuthBloc
    expect(authBloc.state.user?.fullName, 'Nguyen Quan Huy');
    expect(fakeAuthService.updatedUser?.fullName, 'Nguyen Quan Huy');
  });

  testWidgets('DeliveryProfileContent renders without back button when embedded', (tester) async {
    await tester.pumpWidget(buildTestWidget(standalone: false));
    await tester.pumpAndSettle();

    expect(find.text('Hồ sơ của tôi'), findsOneWidget);
    expect(find.text('Tài xế Delicia • Đang hoạt động'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
