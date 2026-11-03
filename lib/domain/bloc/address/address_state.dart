part of 'address_bloc.dart';

@immutable
class AddressState {
  final bool isLoading;
  final bool isMutating;
  final bool realtimeActive;
  final String? error;
  final String? successMessage;
  final List<ClientAddress> addresses;

  /// The user this address list belongs to.
  final String? activeUid;

  const AddressState({
    this.isLoading = false,
    this.isMutating = false,
    this.realtimeActive = false,
    this.error,
    this.successMessage,
    this.addresses = const [],
    this.activeUid,
  });

  bool get isEmpty => !isLoading && addresses.isEmpty;

  /// The address flagged as the user's default, if any.
  ClientAddress? get defaultAddress {
    for (final a in addresses) {
      if (a.isDefault == true) return a;
    }
    return null;
  }

  AddressState copyWith({
    bool? isLoading,
    bool? isMutating,
    bool? realtimeActive,
    String? error,
    String? successMessage,
    List<ClientAddress>? addresses,
    String? activeUid,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return AddressState(
      isLoading: isLoading ?? this.isLoading,
      isMutating: isMutating ?? this.isMutating,
      realtimeActive: realtimeActive ?? this.realtimeActive,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
      addresses: addresses ?? this.addresses,
      activeUid: activeUid ?? this.activeUid,
    );
  }
}