part of 'address_bloc.dart';

@immutable
abstract class AddressEvent {
  const AddressEvent();
}

class OnLoadAddressesEvent extends AddressEvent {
  final String uid;
  const OnLoadAddressesEvent({required this.uid});
}

class OnWatchAddressesEvent extends AddressEvent {
  final String uid;
  const OnWatchAddressesEvent({required this.uid});
}

class OnAddAddressEvent extends AddressEvent {
  final String uid;
  final ClientAddress address;
  const OnAddAddressEvent({required this.uid, required this.address});
}

class OnUpdateAddressEvent extends AddressEvent {
  final String uid;
  final ClientAddress address;
  const OnUpdateAddressEvent({required this.uid, required this.address});
}

class OnDeleteAddressEvent extends AddressEvent {
  final String uid;
  final String addressId;
  const OnDeleteAddressEvent({required this.uid, required this.addressId});
}

class OnSetDefaultAddressEvent extends AddressEvent {
  final String uid;
  final String addressId;
  const OnSetDefaultAddressEvent({required this.uid, required this.addressId});
}

class OnClearAddressesEvent extends AddressEvent {
  const OnClearAddressesEvent();
}

/// Internal: pushed by the realtime listener when the address collection
/// changes.  Keeps the stream callback free of direct `emit` calls.
class OnAddressesPushedEvent extends AddressEvent {
  final List<ClientAddress> addresses;
  const OnAddressesPushedEvent({required this.addresses});
}

/// Internal: pushed by the realtime listener when it errors out.
class OnAddressesWatchFailedEvent extends AddressEvent {
  final String reason;
  const OnAddressesWatchFailedEvent(this.reason);
}
