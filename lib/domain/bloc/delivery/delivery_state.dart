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

  /// `true` after a driver was created — the screen shows the toast and
  /// resets the form.
  final bool driverCreated;

  /// The name of the driver that was just deleted — `null` when nothing
  /// was deleted yet. The screen names the driver in the toast.
  final String? deletedDriverName;

  const DeliveryState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.error,
    this.users = const <DeliveryUser>[],
    this.visibleUsers = const <DeliveryUser>[],
    this.query = '',
    this.actionSucceeded = false,
    this.driverCreated = false,
    this.deletedDriverName,
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
    bool? driverCreated,
    bool clearDriverCreated = false,
    String? deletedDriverName,
    bool clearDeletedDriverName = false,
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
      driverCreated: clearDriverCreated
          ? false
          : (driverCreated ?? this.driverCreated),
      deletedDriverName: clearDeletedDriverName
          ? null
          : (deletedDriverName ?? this.deletedDriverName),
    );
  }
}
