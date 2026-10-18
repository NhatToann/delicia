import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/user.dart';
import '../../services/auth_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

/// AuthBloc — drives UC-01 (Splash + Login + Register + Forgot + Select Role).
///
/// Pattern (per agent.md PHẦN F):
/// - `part of 'auth_bloc.dart'` for events/states (no Freezed).
/// - States: base `AuthState` with [user]/[rolId] + `Loading` / `Failure` /
///   `LogOut` / `ForgotPasswordSuccess` subclasses.
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthService authService})
      : _authService = authService,
        super(const AuthState()) {
    on<LoginEvent>(_onLogin);
    on<CheckLoginEvent>(_onCheckLogin);
    on<ForgotPasswordEvent>(_onForgotPassword);
    on<RegisterEvent>(_onRegister);
    on<LogOutEvent>(_onLogOut);
  }

  final AuthService _authService;

  Future<void> _onLogin(LoginEvent event, Emitter<AuthState> emit) async {
    emit(LoadingAuthState());
    try {
      final user = await _authService.login(event.email, event.password);
      emit(AuthState(user: user, rolId: user.rolId.toString()));
    } on AuthServiceException catch (e) {
      emit(FailureAuthState(e.message));
    } catch (e) {
      emit(FailureAuthState('Unexpected error: $e'));
    }
  }

  Future<void> _onCheckLogin(
    CheckLoginEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(LoadingAuthState());
    final user = await _authService.checkLogin();
    if (user == null) {
      emit(LogOutAuthState());
    } else {
      emit(AuthState(user: user, rolId: user.rolId.toString()));
    }
  }

  Future<void> _onForgotPassword(
    ForgotPasswordEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(LoadingAuthState());
    try {
      await _authService.forgotPassword(event.email);
      emit(ForgotPasswordSuccessState());
    } on AuthServiceException catch (e) {
      emit(FailureAuthState(e.message));
    } catch (e) {
      emit(FailureAuthState('Unexpected error: $e'));
    }
  }

  Future<void> _onLogOut(LogOutEvent event, Emitter<AuthState> emit) async {
    await _authService.logout();
    emit(LogOutAuthState());
  }

  Future<void> _onRegister(
    RegisterEvent event,
    Emitter<AuthState> emit,
  ) async {
    emit(LoadingAuthState());
    try {
      await _authService.register(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
      );
      // After successful registration, sign the user out so they have to log
      // in explicitly (avoids surprising auto-login with empty profile).
      await _authService.logout();
      emit(RegisterSuccessState());
    } on AuthServiceException catch (e) {
      emit(FailureAuthState(e.message));
    } catch (e) {
      emit(FailureAuthState('Unexpected error: $e'));
    }
  }
}
