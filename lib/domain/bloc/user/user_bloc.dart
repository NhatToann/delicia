import 'dart:async';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/user.dart';
import '../../services/client_user_service.dart';

part 'user_event.dart';
part 'user_state.dart';

/// UserBloc — manages the authenticated client's profile (UC-06).
///
/// Responsibilities:
///   - load + watch the profile (first / last name, email, phone, avatar)
///   - update supported profile fields
///   - upload a new avatar to Firebase Storage and persist the URL
///   - reset on logout (the screen / router does the navigation)
///
/// This BLoC is intentionally decoupled from the `AuthBloc` so the
/// address / profile screens can keep working independently; the two
/// coordinate via the active Firebase user UID — that's the single
/// source of truth between them.
class UserBloc extends Bloc<UserEvent, UserState> {
  UserBloc({required ClientUserService userService})
    : _userService = userService,
      super(const UserState()) {
    on<OnLoadUserProfileEvent>(_onLoad);
    on<OnWatchUserProfileEvent>(_onWatch);
    on<OnUpdateUserProfileEvent>(_onUpdate);
    on<OnUploadAvatarEvent>(_onUploadAvatar);
    on<OnUploadAvatarBytesEvent>(_onUploadAvatarBytes);
    on<OnClearUserProfileEvent>(_onClear);
  }

  final ClientUserService _userService;
  StreamSubscription<User?>? _profileSub;

  Future<void> _onLoad(
    OnLoadUserProfileEvent event,
    Emitter<UserState> emit,
  ) async {
    if (event.uid.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: 'Sign in to view your profile.',
          user: null,
          clearError: false,
        ),
      );
      return;
    }
    emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final user = await _userService.loadProfile(event.uid);
      emit(state.copyWith(isLoading: false, user: user, activeUid: event.uid));
    } on ClientUserServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not load profile: $e'),
      );
    }
  }

  Future<void> _onWatch(
    OnWatchUserProfileEvent event,
    Emitter<UserState> emit,
  ) async {
    if (event.uid.isEmpty) return;
    emit(state.copyWith(activeUid: event.uid, clearError: true));
    await _profileSub?.cancel();
    try {
      _profileSub = _userService
          .watchProfile(event.uid)
          .listen(
            (user) {
              if (user == null) return;
              add(OnLoadUserProfileEvent(uid: event.uid));
            },
            onError: (Object e) {
              if (kDebugMode) debugPrint('User profile watch error: $e');
            },
            cancelOnError: false,
          );
    } catch (_) {
      // Watch is best-effort; load still works without it.
    }
  }

  Future<void> _onUpdate(
    OnUpdateUserProfileEvent event,
    Emitter<UserState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to update your profile.'));
      return;
    }
    emit(state.copyWith(isSaving: true, clearError: true));
    try {
      final user = await _userService.updateProfile(
        uid,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
      );
      emit(
        state.copyWith(
          isSaving: false,
          user: user,
          activeUid: uid,
          lastSavedAt: DateTime.now(),
        ),
      );
    } on ClientUserServiceException catch (e) {
      emit(state.copyWith(isSaving: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isSaving: false, error: 'Could not update profile: $e'),
      );
    }
  }

  Future<void> _onUploadAvatar(
    OnUploadAvatarEvent event,
    Emitter<UserState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to change your avatar.'));
      return;
    }
    emit(state.copyWith(isUploadingAvatar: true, clearError: true));
    try {
      final user = await _userService.uploadAvatarFile(uid, event.file);
      emit(
        state.copyWith(isUploadingAvatar: false, user: user, activeUid: uid),
      );
    } on ClientUserServiceException catch (e) {
      emit(state.copyWith(isUploadingAvatar: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          isUploadingAvatar: false,
          error: 'Avatar upload failed: $e',
        ),
      );
    }
  }

  Future<void> _onUploadAvatarBytes(
    OnUploadAvatarBytesEvent event,
    Emitter<UserState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to change your avatar.'));
      return;
    }
    emit(state.copyWith(isUploadingAvatar: true, clearError: true));
    try {
      final user = await _userService.uploadAvatar(
        uid,
        event.bytes,
        mime: event.mime,
      );
      emit(
        state.copyWith(isUploadingAvatar: false, user: user, activeUid: uid),
      );
    } on ClientUserServiceException catch (e) {
      emit(state.copyWith(isUploadingAvatar: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          isUploadingAvatar: false,
          error: 'Avatar upload failed: $e',
        ),
      );
    }
  }

  void _onClear(OnClearUserProfileEvent event, Emitter<UserState> emit) {
    emit(const UserState());
  }

  @override
  Future<void> close() async {
    await _profileSub?.cancel();
    return super.close();
  }
}
