part of 'user_bloc.dart';

@immutable
class UserState {
  final bool isLoading;
  final bool isSaving;
  final bool isUploadingAvatar;
  final String? error;
  final User? user;

  /// The Firebase UID whose profile is currently loaded — used to scope
  /// address / order operations to the right user without crashing on
  /// logout transitions.
  final String? activeUid;

  /// Last successful save timestamp (used to drive a brief inline toast).
  final DateTime? lastSavedAt;

  const UserState({
    this.isLoading = false,
    this.isSaving = false,
    this.isUploadingAvatar = false,
    this.error,
    this.user,
    this.activeUid,
    this.lastSavedAt,
  });

  bool get isBusy => isLoading || isSaving || isUploadingAvatar;

  UserState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? isUploadingAvatar,
    String? error,
    User? user,
    String? activeUid,
    DateTime? lastSavedAt,
    bool clearError = false,
    bool clearLastSaved = false,
  }) {
    return UserState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isUploadingAvatar: isUploadingAvatar ?? this.isUploadingAvatar,
      error: clearError ? null : (error ?? this.error),
      user: user ?? this.user,
      activeUid: activeUid ?? this.activeUid,
      lastSavedAt: clearLastSaved ? null : (lastSavedAt ?? this.lastSavedAt),
    );
  }
}
