part of 'delivery_bloc.dart';

@immutable
class DeliveryState {
  /// True while the first batch of drivers is loading.
  final bool isLoading;

  /// True while an enable / disable write is running.
  final bool isSubmitting;

  /// The last failure, if any.
  final AppFailure? error;

  /// Every delivery driver.
  final List<DeliveryUser> users;

  /// The drivers matching the current [query].
  final List<DeliveryUser> visibleUsers;

  /// The current search text.
  final String query;

  /// `true` after a successful enable / disable.
  final bool actionSucceeded;

  const DeliveryState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.users = const <DeliveryUser>[],
    this.visibleUsers = const <DeliveryUser>[],
    this.query = '',
    this.actionSucceeded = false,
  });

  DeliveryState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    AppFailure? error,
    bool clearError = false,
    List<DeliveryUser>? users,
    List<DeliveryUser>? visibleUsers,
    String? query,
    bool? actionSucceeded,
    bool clearActionSucceeded = false,
  }) {
    return DeliveryState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      users: users ?? this.users,
      visibleUsers: visibleUsers ?? this.visibleUsers,
      query: query ?? this.query,
      actionSucceeded: clearActionSucceeded
          ? false
          : (actionSucceeded ?? this.actionSucceeded),
    );
  }
}
