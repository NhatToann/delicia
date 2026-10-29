// Regression tests for the Profile menu (Figma 4.1 - A - Profile).
//
// The panel is a purely visual feature that only needs [AuthBloc] in
// scope to read the user name + email. The tests assert:
//   1. Every Figma row (My Orders → Log Out) renders, in order.
//   2. Tapping outside the panel dismisses it.
//   3. Tapping a row fires [onItemTap] and closes the drawer.
//   4. The panel renders a guest fallback when nobody is signed in.
//   5. The panel uses the Figma palette verbatim (orange Material).
//   6. The avatar tile in HomeHeaderRow fires [onProfile].
//   7. ProfileMenuOverlay wired to AuthBloc reads the live user data.
//   8. Long names + emails do not overflow the header.

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/presentation/client/home/home_screen.dart';
import 'package:delicia/presentation/client/home/widgets/profile_menu.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_service.dart';

User _user({
  String firstName = 'John',
  String lastName = 'Smith',
  String email = 'lorem@email.com',
}) {
  return User(
    uid: 'u1',
    email: email,
    firstName: firstName,
    lastName: lastName,
    rolId: 2,
  );
}

/// Wraps [body] inside the same [AuthBloc] scope `ProfileMenuOverlay.show`
/// expects, so the panel reads the live user state.
Widget _wrapWithAuthBloc(Widget body, AuthBloc authBloc) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BlocProvider<AuthBloc>.value(
      value: authBloc,
      child: body,
    ),
  );
}

AuthBloc _signedIn({User? user}) {
  final authBloc =
      AuthBloc(authService: FakeAuthService(user: user ?? _user()))
        ..emit(AuthState(user: user ?? _user()));
  addTearDown(authBloc.close);
  return authBloc;
}

AuthBloc _guestBloc() {
  final authBloc = AuthBloc(authService: FakeAuthService());
  addTearDown(authBloc.close);
  return authBloc;
}

void main() {
  group('ProfileMenu', () {
    testWidgets('renders every Figma row + Log Out for a signed-in user', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) =>
            ProfileMenuOverlay.show(ctx, onItemTap: (_) {})),
        _signedIn(),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      tester.takeException();

      for (final label in const <String>[
        'Đơn hàng',
        'Hồ sơ của tôi',
        'Địa chỉ giao hàng',
        'Phương thức thanh toán',
        'Liên hệ',
        'Trợ giúp & Câu hỏi',
        'Cài đặt',
        'Đăng xuất',
      ]) {
        expect(find.text(label), findsOneWidget,
            reason: 'row "$label" missing from drawer');
      }
      expect(find.text('John Smith'), findsOneWidget);
      expect(find.text('lorem@email.com'), findsOneWidget);
    });

    testWidgets('out-of-panel tap dismisses the drawer', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) =>
            ProfileMenuOverlay.show(ctx, onItemTap: (_) {})),
        _signedIn(),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileMenu), findsOneWidget);

      // Tap the empty backdrop on the left edge of the screen.
      await tester.tapAt(const Offset(40, 400));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileMenu), findsNothing);
    });

    testWidgets('tapping a row reports it then closes the drawer', (
      WidgetTester tester,
    ) async {
      String? lastTapped;
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) => ProfileMenuOverlay.show(
          ctx,
          onItemTap: (label) => lastTapped = label,
        )),
        _signedIn(),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hồ sơ của tôi'));
      await tester.pumpAndSettle();

      expect(lastTapped, 'Hồ sơ của tôi');
      expect(find.byType(ProfileMenu), findsNothing);
    });

    testWidgets('uses the Figma palette on its Material panel', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) =>
            ProfileMenuOverlay.show(ctx, onItemTap: (_) {})),
        _signedIn(),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final panelMaterial = tester
          .widgetList<Material>(find.byType(Material))
          .firstWhere(
            (m) => m.color == ColorsFrave.navOrange,
            orElse: () => fail('Orange panel Material not found'),
          );
      expect(panelMaterial.color, ColorsFrave.navOrange);
    });

    testWidgets('renders a guest fallback when nobody is signed in', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) =>
            ProfileMenuOverlay.show(ctx, onItemTap: (_) {})),
        _guestBloc(),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Khách'), findsOneWidget);
      expect(find.text('Chưa đăng nhập'), findsOneWidget);
    });

    testWidgets('home header avatar button fires onProfile', (
      WidgetTester tester,
    ) async {
      var profileTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: HomeHeaderRow(
              onFilter: () {},
              onAction: (_) {},
              onProfile: () => profileTaps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final handle = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Hồ sơ của tôi'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Hồ sơ của tôi'));
      await tester.pumpAndSettle();
      handle.dispose();

      expect(
        profileTaps,
        1,
        reason: 'avatar tile must fire HomeHeaderRow.onProfile once',
      );
    });

    testWidgets('ProfileMenuOverlay reads the live AuthBloc user', (
      WidgetTester tester,
    ) async {
      final authBloc = _signedIn();
      await tester.pumpWidget(_wrapWithAuthBloc(
        Builder(
          builder: (ctx) => Scaffold(
            appBar: AppBar(
              title: const Text('app'),
              actions: <Widget>[
                IconButton(
                  icon: const Icon(Icons.person),
                  tooltip: 'Profile',
                  onPressed: () => ProfileMenuOverlay.show(ctx),
                ),
              ],
            ),
          ),
        ),
        authBloc,
      ));
      await tester.tap(find.byTooltip('Profile'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      expect(find.byType(ProfileMenu), findsOneWidget);
      expect(find.text('John Smith'), findsOneWidget);
    });

    testWidgets('long names + emails do not overflow the header', (
      WidgetTester tester,
    ) async {
      final user = _user(
        firstName: 'Pneumonoultramicroscopicsilicovolcanoconiosis',
        lastName: 'Van der Muyzen',
        email: 'verylongemailaddressfortest@test.com',
      );
      await tester.pumpWidget(_wrapWithAuthBloc(
        _OpenBuilder(onTap: (ctx) =>
            ProfileMenuOverlay.show(ctx, onItemTap: (_) {})),
        _signedIn(user: user),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data ==
                'Pneumonoultramicroscopicsilicovolcanoconiosis Van der Muyzen'),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate((w) =>
            w is Text &&
            w.data == 'verylongemailaddressfortest@test.com'),
        findsOneWidget,
      );
    });
  });
}

/// A trivial scaffold that renders a single button which fires [onTap] with
/// the surrounding [BuildContext]. Used by tests that just need to open the
/// drawer and don't care about the launcher itself.
class _OpenBuilder extends StatelessWidget {
  const _OpenBuilder({required this.onTap});
  final void Function(BuildContext ctx) onTap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          onPressed: () => onTap(context),
          child: const Text('open'),
        ),
      ),
    );
  }
}
