part of 'auth_bloc.dart';

@immutable
abstract class AuthEvent {}

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
