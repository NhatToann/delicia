import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/client_address.dart';
import '../../services/client_address_service.dart';

part 'address_event.dart';
part 'address_state.dart';

/// AddressBloc — CRUD for the authenticated client's delivery addresses
/// (UC-06).  All operations are scoped to a single UID passed at runtime
/// (typically `AuthBloc.state.user?.uid`).
class AddressBloc extends Bloc<AddressEvent, AddressState> {
  AddressBloc({required this._addressService})
    : super(const AddressState()) {
    on<OnLoadAddressesEvent>(_onLoad);    on<OnWatchAddressesEvent>(_onWatch);
    on<OnAddAddressEvent>(_onAdd);
    on<OnUpdateAddressEvent>(_onUpdate);
    on<OnDeleteAddressEvent>(_onDelete);
    on<OnSetDefaultAddressEvent>(_onSetDefault);
    on<OnClearAddressesEvent>(_onClear);
    on<OnAddressesPushedEvent>(
      (event, emit) => emit(state.copyWith(addresses: event.addresses)),
    );
    on<OnAddressesWatchFailedEvent>(
      (event, emit) => emit(
        state.copyWith(
          realtimeActive: false,
          error: 'Realtime listener unavailable: ${event.reason}',
        ),
      ),
    );
  }

  final ClientAddressService _addressService;
  StreamSubscription<List<ClientAddress>>? _watchSub;

  Future<void> _onLoad(
    OnLoadAddressesEvent event,
    Emitter<AddressState> emit,
  ) async {
    if (event.uid.isEmpty) {
      emit(
        state.copyWith(
          isLoading: false,
          error: null,
          addresses: const [],
          activeUid: '',
        ),
      );
      return;
    }
    emit(
      state.copyWith(isLoading: true, activeUid: event.uid, clearError: true),
    );
    try {
      final list = await _addressService.listAddresses(event.uid);
      emit(state.copyWith(isLoading: false, addresses: list));
    } on ClientAddressServiceException catch (e) {
      emit(state.copyWith(isLoading: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isLoading: false, error: 'Could not load addresses: $e'),
      );
    }
  }

  Future<void> _onWatch(
    OnWatchAddressesEvent event,
    Emitter<AddressState> emit,
  ) async {
    if (event.uid.isEmpty) return;
    emit(state.copyWith(activeUid: event.uid, clearError: true));
    await _watchSub?.cancel();
    try {
      // Stream callbacks must never call `emit` directly (the handler is
      // already complete by then) — re-dispatch instead so the BLoC owns
      // every state transition.
      _watchSub = _addressService
          .watchAddresses(event.uid)
          .listen(
            (list) => add(OnAddressesPushedEvent(addresses: list)),
            onError: (Object e) => add(OnAddressesWatchFailedEvent('$e')),
            cancelOnError: false,
          );
    } catch (e) {
      emit(
        state.copyWith(
          realtimeActive: false,
          error: 'Could not watch addresses: $e',
        ),
      );
      return;
    }
    emit(state.copyWith(realtimeActive: true));
  }

  Future<void> _onAdd(
    OnAddAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to save an address.'));
      return;
    }
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      await _addressService.addAddress(uid, event.address);
      emit(state.copyWith(isMutating: false, activeUid: uid));
      // Refresh from source so the new address shows up in the list.
      add(OnLoadAddressesEvent(uid: uid));
    } on ClientAddressServiceException catch (e) {
      emit(state.copyWith(isMutating: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isMutating: false, error: 'Could not save address: $e'),
      );
    }
  }

  Future<void> _onUpdate(
    OnUpdateAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to update an address.'));
      return;
    }
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      await _addressService.updateAddress(uid, event.address);
      emit(state.copyWith(isMutating: false, activeUid: uid));
      add(OnLoadAddressesEvent(uid: uid));
    } on ClientAddressServiceException catch (e) {
      emit(state.copyWith(isMutating: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          isMutating: false,
          error: 'Could not update address: $e',
        ),
      );
    }
  }

  Future<void> _onDelete(
    OnDeleteAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to delete an address.'));
      return;
    }
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      await _addressService.deleteAddress(uid, event.addressId);
      emit(state.copyWith(isMutating: false, activeUid: uid));
      add(OnLoadAddressesEvent(uid: uid));
    } on ClientAddressServiceException catch (e) {
      emit(state.copyWith(isMutating: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(
          isMutating: false,
          error: 'Could not delete address: $e',
        ),
      );
    }
  }

  Future<void> _onSetDefault(
    OnSetDefaultAddressEvent event,
    Emitter<AddressState> emit,
  ) async {
    final uid = event.uid.isEmpty ? (state.activeUid ?? '') : event.uid;
    if (uid.isEmpty) {
      emit(state.copyWith(error: 'Sign in to set a default address.'));
      return;
    }
    emit(state.copyWith(isMutating: true, clearError: true));
    try {
      await _addressService.setDefault(uid, event.addressId);
      emit(state.copyWith(isMutating: false, activeUid: uid));
      add(OnLoadAddressesEvent(uid: uid));
    } on ClientAddressServiceException catch (e) {
      emit(state.copyWith(isMutating: false, error: e.message));
    } catch (e) {
      emit(
        state.copyWith(isMutating: false, error: 'Could not set default: $e'),
      );
    }
  }

  void _onClear(OnClearAddressesEvent event, Emitter<AddressState> emit) {
    emit(const AddressState());
  }

  @override
  Future<void> close() async {
    await _watchSub?.cancel();
    return super.close();
  }
}
