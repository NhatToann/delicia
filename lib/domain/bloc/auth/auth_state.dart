part of 'auth_bloc.dart';

@immutable
class AuthState {
  final User? user;
  final String rolId;
  // Nullable while reading to stay safe across Flutter hot reloads: an
  // AuthState instance created before these fields existed can temporarily
  // expose null until the bloc emits a fresh state.
  final bool? isUpdatingProfile;
  final AppFailure? profileUpdateError;
  final int? profileUpdateVersion;

  const AuthState({
    this.user,
    this.rolId = '',
    this.isUpdatingProfile = false,
    this.profileUpdateError,
    this.profileUpdateVersion = 0,
  });

  AuthState copyWith({
    User? user,
    String? rolId,
    bool? isUpdatingProfile,
    AppFailure? profileUpdateError,
    bool clearProfileUpdateError = false,
    int? profileUpdateVersion,
  }) {
    return AuthState(
      user: user ?? this.user,
      rolId: rolId ?? this.rolId,
      isUpdatingProfile:
          isUpdatingProfile ?? this.isUpdatingProfile ?? false,
      profileUpdateError: clearProfileUpdateError
          ? null
          : (profileUpdateError ?? this.profileUpdateError),
      profileUpdateVersion:
          profileUpdateVersion ?? this.profileUpdateVersion ?? 0,
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
  /// The failure, carrying a stable code the UI can translate.
  final AppFailure error;
  const FailureAuthState(this.error);
}

class ForgotPasswordSuccessState extends AuthState {
  const ForgotPasswordSuccessState();
}

class RegisterSuccessState extends AuthState {
  const RegisterSuccessState();
}
