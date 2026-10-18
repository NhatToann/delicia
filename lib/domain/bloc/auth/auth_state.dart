part of 'auth_bloc.dart';

@immutable
class AuthState {
  final User? user;
  final String rolId;

  const AuthState({this.user, this.rolId = ''});

  AuthState copyWith({User? user, String? rolId}) {
    return AuthState(
      user: user ?? this.user,
      rolId: rolId ?? this.rolId,
    );
  }
}

class LoadingAuthState extends AuthState {
  const LoadingAuthState();
}

class SuccessAuthState extends AuthState {
  const SuccessAuthState();
}

class LogOutAuthState extends AuthState {
  const LogOutAuthState();
}

class FailureAuthState extends AuthState {
  final String error;
  const FailureAuthState(this.error);
}

class ForgotPasswordSuccessState extends AuthState {
  const ForgotPasswordSuccessState();
}

class RegisterSuccessState extends AuthState {
  const RegisterSuccessState();
}
