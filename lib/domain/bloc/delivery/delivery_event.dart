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
