part of 'delivery_bloc.dart';

@immutable
abstract class DeliveryEvent {
  const DeliveryEvent();
}

/// Opens (or re-opens) the live driver feed.
class DeliveryUsersLoadRequested extends DeliveryEvent {
  const DeliveryUsersLoadRequested();
}

/// Filters the visible list by name / phone / email.
class DeliveryUserSearchChanged extends DeliveryEvent {
  const DeliveryUserSearchChanged(this.query);
  final String query;
}

/// Enables or disables a driver account.
class DeliveryUserEnabledChanged extends DeliveryEvent {
  const DeliveryUserEnabledChanged({required this.uid, required this.enabled});
  final String uid;
  final bool enabled;
}

/// Creates a brand-new driver account.
class DeliveryUserCreated extends DeliveryEvent {
  const DeliveryUserCreated({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    this.phone,
  });

  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String? phone;
}

/// Removes a driver account for good.
class DeliveryUserDeleted extends DeliveryEvent {
  const DeliveryUserDeleted({
    required this.uid,
    required this.email,
    required this.name,
  });
  final String uid;
  final String email;

  /// The driver's display name — carried along so the screen can name
  /// the driver in the confirmation toast.
  final String name;
}

/// Internal event — a new batch of drivers arrived.
class _DeliveryUsersUpdated extends DeliveryEvent {
  const _DeliveryUsersUpdated(this.users);
  final List<DeliveryUser> users;
}

/// Internal event — the driver feed failed.
class _DeliveryUsersFailed extends DeliveryEvent {
  const _DeliveryUsersFailed(this.error);
  final Object error;
}
