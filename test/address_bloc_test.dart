// UC-06 — AddressBloc unit tests. Uses an in-memory [_FakeAddressService].

import 'dart:async';

import 'package:delicia/domain/bloc/address/address_bloc.dart';
import 'package:delicia/domain/models/client_address.dart';
import 'package:delicia/domain/services/client_address_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAddressService implements ClientAddressService {
  _FakeAddressService({this.throwOnAdd = false});
  bool throwOnAdd;
  final List<ClientAddress> stored = [];
  final StreamController<List<ClientAddress>> _watchController =
      StreamController<List<ClientAddress>>.broadcast();

  @override
  Future<List<ClientAddress>> listAddresses(String uid) async =>
      List<ClientAddress>.from(stored);

  @override
  Stream<List<ClientAddress>> watchAddresses(String uid) => _watchController.stream;

  @override
  Future<ClientAddress> addAddress(String uid, ClientAddress address) async {
    if (throwOnAdd) {
      throw ClientAddressServiceException('add failed');
    }
    final storedAddr = ClientAddress(
      id: address.id.isEmpty ? 'new-${stored.length + 1}' : address.id,
      street: address.street,
      reference: address.reference,
      latitude: address.latitude,
      longitude: address.longitude,
      isDefault: address.isDefault,
    );
    stored.add(storedAddr);
    _watchController.add(List<ClientAddress>.from(stored));
    return storedAddr;
  }

  @override
  Future<ClientAddress> updateAddress(String uid, ClientAddress address) async {
    final i = stored.indexWhere((a) => a.id == address.id);
    if (i == -1) {
      stored.add(address);
    } else {
      stored[i] = address;
    }
    _watchController.add(List<ClientAddress>.from(stored));
    return address;
  }

  @override
  Future<void> deleteAddress(String uid, String addressId) async {
    stored.removeWhere((a) => a.id == addressId);
    _watchController.add(List<ClientAddress>.from(stored));
  }

  @override
  Future<void> setDefault(String uid, String addressId) async {
    for (var i = 0; i < stored.length; i++) {
      stored[i] = ClientAddress(
        id: stored[i].id,
        street: stored[i].street,
        reference: stored[i].reference,
        latitude: stored[i].latitude,
        longitude: stored[i].longitude,
        isDefault: stored[i].id == addressId,
      );
    }
    _watchController.add(List<ClientAddress>.from(stored));
  }
}

void main() {
  group('AddressBloc', () {
    test('initial state has an empty address list', () {
      final bloc = AddressBloc(addressService: _FakeAddressService());
      expect(bloc.state.addresses, isEmpty);
      expect(bloc.state.isLoading, isFalse);
    });

    test('loads the user\'s addresses from the service', () async {
      final svc = _FakeAddressService()
        ..stored.addAll([
          ClientAddress(
            id: 'a1',
            street: '1 Lê Lợi',
            reference: 'District 1',
            latitude: 10,
            longitude: 106,
            isDefault: true,
          ),
        ]);
      final bloc = AddressBloc(addressService: svc);
      bloc.add(const OnLoadAddressesEvent(uid: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isLoading, isFalse);
      expect(bloc.state.addresses.length, 1);
      expect(bloc.state.defaultAddress?.id, 'a1');
    });

    test('returns a user-friendly error when add fails', () async {
      final svc = _FakeAddressService(throwOnAdd: true);
      final bloc = AddressBloc(addressService: svc);
      bloc.add(
        OnAddAddressEvent(
          uid: 'user-1',
          address: ClientAddress(
            id: '',
            street: '',
            reference: '',
            latitude: 0,
            longitude: 0,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.isMutating, isFalse);
      expect(bloc.state.error, contains('add failed'));
    });

    test('rejects operations when the uid is empty', () async {
      final bloc = AddressBloc(addressService: _FakeAddressService());
      bloc.add(
        const OnAddAddressEvent(
          uid: '',
          address: ClientAddress(
            id: '',
            street: 'X',
            reference: '',
            latitude: 0,
            longitude: 0,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.error, contains('Sign in'));
    });

    test('delete removes the address from the list', () async {
      final svc = _FakeAddressService()
        ..stored.addAll([
          ClientAddress(
            id: 'a1',
            street: '1',
            reference: '',
            latitude: 0,
            longitude: 0,
            isDefault: false,
          ),
          ClientAddress(
            id: 'a2',
            street: '2',
            reference: '',
            latitude: 0,
            longitude: 0,
            isDefault: false,
          ),
        ]);
      final bloc = AddressBloc(addressService: svc);
      bloc.add(const OnDeleteAddressEvent(uid: 'user-1', addressId: 'a1'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.addresses.length, 1);
      expect(bloc.state.addresses.first.id, 'a2');
    });

    test('set-default clears the previous default', () async {
      final svc = _FakeAddressService()
        ..stored.addAll([
          ClientAddress(
            id: 'a1',
            street: '1',
            reference: '',
            latitude: 0,
            longitude: 0,
            isDefault: true,
          ),
          ClientAddress(
            id: 'a2',
            street: '2',
            reference: '',
            latitude: 0,
            longitude: 0,
            isDefault: false,
          ),
        ]);
      final bloc = AddressBloc(addressService: svc);
      bloc.add(const OnSetDefaultAddressEvent(uid: 'user-1', addressId: 'a2'));
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(bloc.state.defaultAddress?.id, 'a2');
      expect(
        bloc.state.addresses.firstWhere((a) => a.id == 'a1').isDefault,
        isFalse,
      );
    });

    test('clear event resets the state', () async {
      final svc = _FakeAddressService()
        ..stored.addAll([
          ClientAddress(
            id: 'a1',
            street: '1',
            reference: '',
            latitude: 0,
            longitude: 0,
            isDefault: true,
          ),
        ]);
      final bloc = AddressBloc(addressService: svc);
      bloc.add(const OnLoadAddressesEvent(uid: 'user-1'));
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.addresses, isNotEmpty);
      bloc.add(const OnClearAddressesEvent());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(bloc.state.addresses, isEmpty);
      expect(bloc.state.activeUid, isNull);
    });
  });
}
