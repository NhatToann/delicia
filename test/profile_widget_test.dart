// UC-06 — Widget tests for ProfileScreen.
//
// We avoid touching the platform image picker by stubbing the
// ClientUserService in-memory and asserting the form / button text + state
// behaviour.

import 'dart:typed_data';

import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/user/user_bloc.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/client_user_service.dart';
import 'package:delicia/presentation/client/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/stub_auth_service.dart';

// StubAuthService — delegated to the shared helper in
// test/test_helpers/stub_auth_service.dart.

class _SeedUserService implements ClientUserService {
  User user;
  _SeedUserService(this.user);

  @override
  Future<User> loadProfile(String uid) async => user;

  @override
  Future<User> updateProfile(
    String uid, {
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    user = User(
      uid: uid,
      email: user.email,
      firstName: firstName ?? user.firstName,
      lastName: lastName ?? user.lastName,
      phone: phone ?? user.phone,
      image: user.image,
      rolId: user.rolId,
    );
    return user;
  }

  @override
  Future<User> uploadAvatar(
    String uid,
    Uint8List bytes, {
    String? mime,
  }) async => user;

  @override
  Future<User> uploadAvatarFile(String uid, dynamic file) async => user;

  Future<User> uploadAvatarBytes(String uid, Uint8List bytes) async => user;

  @override
  Stream<User?> watchProfile(String uid) async* {
    yield user;
  }

  @override
  Future<Uint8List?> loadAvatarBytes(String uid) async => null;
}

Future<void> seedAuth(WidgetTester tester, AuthBloc auth) async {
  auth.add(CheckLoginEvent());
  await tester.pump();
  await tester.pump();
}

/// Let microtasks (stream emissions, async service returns) settle without
/// using `pumpAndSettle` — the fake services use `Stream.value(...)` whose
/// emissions never end, so pumpAndSettle would hang.
Future<void> settleMicrotasks(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('ProfileScreen renders user fields and "Sign out" button', (
    tester,
  ) async {
    final user = User(
      uid: 'user-1',
      email: 'a@b.com',
      firstName: 'Alice',
      lastName: 'Doe',
      phone: '+84123',
      image: null,
      rolId: 2,
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final userBloc = UserBloc(userService: _SeedUserService(user));
    addTearDown(auth.close);
    addTearDown(userBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<UserBloc>.value(value: userBloc),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    expect(find.text('My Profile'), findsOneWidget);
    // The save CTA lives below the fold of the profile ListView.
    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Save changes'), findsOneWidget);
    expect(find.text('Manage addresses'), findsOneWidget);
    // The sign-out button sits at the very bottom of the list — scroll it
    // into view before asserting, otherwise it isn't built yet.
    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Sign out'), findsOneWidget);
    // Field labels render (each also appears as the TextField's own label,
    // so match loosely rather than pinning an exact count).
    expect(find.text('First name'), findsWidgets);
    expect(find.text('Last name'), findsWidgets);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Phone number'), findsWidgets);
  });

  testWidgets('Validation marks empty first name invalid', (tester) async {
    final user = User(
      uid: 'user-1',
      email: 'a@b.com',
      firstName: '',
      lastName: '',
      phone: '',
      image: null,
      rolId: 2,
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final userBloc = UserBloc(userService: _SeedUserService(user));
    addTearDown(auth.close);
    addTearDown(userBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<UserBloc>.value(value: userBloc),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    await tester.scrollUntilVisible(
      find.text('Save changes'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Save changes'));
    await settleMicrotasks(tester);

    expect(find.text('First name is required'), findsOneWidget);
    expect(find.text('Last name is required'), findsOneWidget);
  });

  testWidgets('Sign out confirms, dismisses the loader and leaves no dialog', (
    tester,
  ) async {
    final user = User(
      uid: 'user-1',
      email: 'a@b.com',
      firstName: 'Alice',
      lastName: 'Doe',
      phone: '+84123',
      image: null,
      rolId: 2,
    );
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final userBloc = UserBloc(userService: _SeedUserService(user));
    addTearDown(auth.close);
    addTearDown(userBloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<UserBloc>.value(value: userBloc),
          ],
          child: const ProfileScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    await tester.scrollUntilVisible(
      find.text('Sign out'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    // The sign-out button sits at the very bottom of the profile list; on a
    // short test viewport it can still be a few pixels outside the frame
    // even after scrolling, so pull it fully into view before tapping.
    await tester.ensureVisible(find.text('Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign out'));
    await settleMicrotasks(tester);

    // Confirmation dialog appears.
    expect(find.text('Sign out?'), findsOneWidget);
    // Tap the dialog's own "Sign out" action. The page behind the dialog
    // also renders a "Sign out" button, so scope the finder to the dialog.
    final confirmButton = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(ElevatedButton, 'Sign out'),
    );
    expect(confirmButton, findsOneWidget);
    await tester.tap(confirmButton);
    await settleMicrotasks(tester);
    // Let the dialog's exit transition finish — the loading dialog is
    // still in the widget tree while it animates away.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    // The loading dialog must NOT stay on screen: the sign-out used to
    // `await modalLoading(...)`, which deadlocked because the dialog future
    // only completes once the dialog is popped.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    // The confirm dialog is gone too.
    expect(find.text('Sign out?'), findsNothing);
  });
}
