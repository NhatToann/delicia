// UC-01 — AuthBloc unit tests using a fake [AuthService].
//
// We exercise the four events described in agent.md PHẦN F:
//   LoginEvent, CheckLoginEvent, ForgotPasswordEvent, LogOutEvent.
//
// The fake service avoids hitting Firebase during testing.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/models/user.dart';
import 'package:delicia/domain/services/app_failure.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAuthService implements AuthService {
  _FakeAuthService({this.shouldThrow = false, this.user});
  bool shouldThrow;
  User? user;

  @override
  Future<User> login(String email, String password) async {
    if (shouldThrow) {
      throw const AuthServiceException(
        AppFailureCodes.authInvalidCredentials,
      );
    }
    return user ??
        User(
          uid: 'u1',
          email: email,
          firstName: 'Test',
          lastName: 'User',
          rolId: 2,
        );
  }

  @override
  Future<void> forgotPassword(String email) async {
    if (shouldThrow) {
      throw const AuthServiceException(AppFailureCodes.authLoginNoUser);
    }
  }

  @override
  Future<User> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    String? phone,
    int rolId = 2,
  }) async {
    if (shouldThrow) {
      throw const AuthServiceException(AppFailureCodes.authEmailInUse);
    }
    return User(
      uid: 'u-new',
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      rolId: rolId,
    );
  }

  @override
  Future<User?> checkLogin() async => user;

  @override
  Future<void> logout() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthBloc', () {
    test('initial state is empty AuthState', () {
      final bloc = AuthBloc(authService: _FakeAuthService());
      expect(bloc.state, isA<AuthState>());
      expect(bloc.state.rolId, '');
    });

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, AuthState(rolId=2)] on successful LoginEvent',
      build: () => AuthBloc(authService: _FakeAuthService()),
      act: (bloc) => bloc.add(LoginEvent('a@b.com', '123456')),
      expect: () => [
        isA<LoadingAuthState>(),
        isA<AuthState>().having((s) => s.rolId, 'rolId', '2'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, FailureAuthState] when login throws',
      build: () =>
          AuthBloc(authService: _FakeAuthService(shouldThrow: true)),
      act: (bloc) => bloc.add(LoginEvent('a@b.com', 'wrong')),
      expect: () => [
        isA<LoadingAuthState>(),
        isA<FailureAuthState>().having(
          (s) => s.error.code,
          'error code',
          AppFailureCodes.authInvalidCredentials,
        ),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits LogOutAuthState when checkLogin returns null',
      build: () => AuthBloc(authService: _FakeAuthService(user: null)),
      act: (bloc) => bloc.add(CheckLoginEvent()),
      expect: () => [isA<LoadingAuthState>(), isA<LogOutAuthState>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits ForgotPasswordSuccessState on successful forgotPassword',
      build: () => AuthBloc(authService: _FakeAuthService()),
      act: (bloc) => bloc.add(ForgotPasswordEvent('a@b.com')),
      expect: () => [
        isA<LoadingAuthState>(),
        isA<ForgotPasswordSuccessState>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits LogOutAuthState on LogOutEvent',
      build: () => AuthBloc(authService: _FakeAuthService()),
      act: (bloc) => bloc.add(LogOutEvent()),
      expect: () => [isA<LogOutAuthState>()],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, RegisterSuccessState] on successful RegisterEvent',
      build: () => AuthBloc(authService: _FakeAuthService()),
      act: (bloc) => bloc.add(RegisterEvent(
            email: 'new@user.com',
            password: 'secret1',
            firstName: 'New',
            lastName: 'User',
            phone: '+84901234567',
          )),
      expect: () => [
        isA<LoadingAuthState>(),
        isA<RegisterSuccessState>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      'emits [Loading, FailureAuthState] when register throws',
      build: () =>
          AuthBloc(authService: _FakeAuthService(shouldThrow: true)),
      act: (bloc) => bloc.add(RegisterEvent(
            email: 'dup@user.com',
            password: 'secret1',
            firstName: 'Dup',
            lastName: 'User',
          )),
      expect: () => [
        isA<LoadingAuthState>(),
        isA<FailureAuthState>().having(
          (s) => s.error.code,
          'error code',
          AppFailureCodes.authEmailInUse,
        ),
      ],
    );
  });
}
