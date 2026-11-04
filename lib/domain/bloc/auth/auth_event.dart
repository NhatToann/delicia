part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent {
  const AuthEvent();
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;
  LoginEvent(this.email, this.password);
}

class CheckLoginEvent extends AuthEvent {}

class ForgotPasswordEvent extends AuthEvent {
  final String email;
  ForgotPasswordEvent(this.email);
}

class RegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? phone;

  RegisterEvent({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.phone,
  });
}

class LogOutEvent extends AuthEvent {}

/// Refreshes the locally-cached user without touching Firebase.
///
/// The UC-06 profile screen saves through `UserBloc` (its own service
/// contract). The profile menu also renders the cached user, so after a
/// successful save the two blocs have to agree — this event lets the
/// profile screen push the fresh user into `AuthBloc` through the normal
/// event pipeline instead of calling the protected `emit` directly.
class OnSyncLocalUserEvent extends AuthEvent {
  const OnSyncLocalUserEvent(this.user);
  final User user;
}

class UpdateProfileEvent extends AuthEvent {
  UpdateProfileEvent({
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.dateOfBirth,
    this.profileImageBytes,
    this.profileImageContentType,
  });

  final String firstName;
  final String lastName;
  final String phone;
  final String dateOfBirth;
  final Uint8List? profileImageBytes;
  final String? profileImageContentType;
}
