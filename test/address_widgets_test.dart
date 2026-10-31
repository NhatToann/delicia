// UC-06 — Widget tests for AddressListScreen and AddressFormScreen.
//
// The screens render their copy through `context.l10n`, so the assertions
// below use `viL10n` — the same Vietnamese table the production code
// resolves — instead of hard-coded literals.

import 'package:delicia/domain/bloc/address/address_bloc.dart';
import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/models/client_address.dart';
import 'package:delicia/domain/services/client_address_service.dart';
import 'package:delicia/presentation/client/profile/address_form_screen.dart';
import 'package:delicia/presentation/client/profile/address_list_screen.dart';
import 'package:delicia/presentation/helpers/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers/stub_auth_service.dart';

class _SeedAddressService implements ClientAddressService {
  final List<ClientAddress> stored;
  _SeedAddressService(this.stored);

  @override
  Future<List<ClientAddress>> listAddresses(String uid) async => stored;

  @override
  Stream<List<ClientAddress>> watchAddresses(String uid) async* {
    yield stored;
  }

  @override
  Future<ClientAddress> addAddress(String uid, ClientAddress address) async =>
      throw UnimplementedError();

  @override
  Future<ClientAddress> updateAddress(String uid, ClientAddress address) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAddress(String uid, String addressId) async {}

  @override
  Future<void> setDefault(String uid, String addressId) async {}
}

/// Drives [AuthBloc] to its authenticated state so the screens can resolve
/// a uid. The stub service never touches Firebase.
Future<void> seedAuth(WidgetTester tester, AuthBloc auth) async {
  auth.add(CheckLoginEvent());
  await tester.pump();
  await tester.pump();
}

/// Let microtasks (stream emissions, async service returns) settle without
/// using `pumpAndSettle` — the fake services use `Stream.value/async*`
/// whose emissions never end, so pumpAndSettle would hang.
Future<void> settleMicrotasks(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('AddressListScreen shows the empty state when no addresses', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final address = AddressBloc(addressService: _SeedAddressService(const []));
    addTearDown(auth.close);
    addTearDown(address.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<AddressBloc>.value(value: address),
          ],
          child: const AddressListScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    expect(find.text(viL10n.addressEmptyTitle), findsOneWidget);
    // Rendered twice on purpose: the empty-state CTA and the app-bar action.
    expect(find.text(viL10n.addressAdd), findsWidgets);
  });

  testWidgets('AddressListScreen shows existing addresses with default badge', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final address = AddressBloc(
      addressService: _SeedAddressService([
        ClientAddress(
          id: 'a1',
          street: '1 Lê Lợi',
          reference: 'District 1',
          latitude: 10,
          longitude: 106,
          isDefault: true,
        ),
        ClientAddress(
          id: 'a2',
          street: '2 Nguyễn Huệ',
          reference: 'District 1',
          latitude: 10.772,
          longitude: 106.704,
          isDefault: false,
        ),
      ]),
    );
    addTearDown(auth.close);
    addTearDown(address.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<AddressBloc>.value(value: address),
          ],
          child: const AddressListScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    expect(find.text('1 Lê Lợi'), findsOneWidget);
    expect(find.text('2 Nguyễn Huệ'), findsOneWidget);
    expect(find.text(viL10n.addressDefault), findsOneWidget);
    expect(find.text(viL10n.addressSetDefault), findsOneWidget);
    expect(find.text(viL10n.actionEdit), findsWidgets);
    expect(find.text(viL10n.addressDelete), findsWidgets);
  });

  testWidgets('AddressFormScreen validates empty street + coordinates', (
    tester,
  ) async {
    final auth = AuthBloc(authService: StubAuthService.loggedIn());
    final address = AddressBloc(addressService: _SeedAddressService(const []));
    addTearDown(auth.close);
    addTearDown(address.close);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>.value(value: auth),
            BlocProvider<AddressBloc>.value(value: address),
          ],
          child: const AddressFormScreen(),
        ),
      ),
    );
    await seedAuth(tester, auth);
    await settleMicrotasks(tester);

    // Submit without filling fields — should not pop and validation should
    // show errors. The submit CTA is inside the scroll view, hence the
    // explicit scroll before tapping.
    await tester.scrollUntilVisible(
      find.text(viL10n.addressSave).first,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(viL10n.addressSave).first);
    await settleMicrotasks(tester);
    expect(find.text(viL10n.addressStreetRequired), findsOneWidget);
    expect(find.text(viL10n.addressCoordinateRequired), findsNWidgets(2));
  });

  testWidgets(
    'AddressFormScreen prefills fields when an existing address is passed',
    (tester) async {
      final auth = AuthBloc(authService: StubAuthService.loggedIn());
      final address = AddressBloc(
        addressService: _SeedAddressService(const []),
      );
      addTearDown(auth.close);
      addTearDown(address.close);

      final existing = ClientAddress(
        id: 'a1',
        street: 'Existing Street',
        reference: 'ref',
        latitude: 10.5,
        longitude: 106.5,
        isDefault: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<AuthBloc>.value(value: auth),
              BlocProvider<AddressBloc>.value(value: address),
            ],
            child: AddressFormScreen(existingAddress: existing),
          ),
        ),
      );
      await seedAuth(tester, auth);
      await settleMicrotasks(tester);

      expect(find.text('Existing Street'), findsOneWidget);
      expect(find.text('ref'), findsOneWidget);
      expect(find.text(viL10n.addressSaveChanges), findsOneWidget);
    },
  );
}
