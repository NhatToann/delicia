// UC-09 — DeliveryBloc tests.
//
// Covers:
//   * the realtime driver feed,
//   * the search filter,
//   * the enable / disable toggle (the happy path and the failure).

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/delivery/delivery_bloc.dart';
import 'package:delicia/domain/models/delivery_user.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

DeliveryUser _driver({
  required String uid,
  String name = 'Nguyễn Tài xế',
  String phone = '0900000000',
  bool isEnabled = true,
}) {
  return DeliveryUser(
    uid: uid,
    name: name,
    phone: phone,
    isEnabled: isEnabled,
  );
}

void main() {
  group('DeliveryBloc — feed & search', () {
    blocTest<DeliveryBloc, DeliveryState>(
      'stores the drivers that arrive on the stream',
      build: () => DeliveryBloc(
        deliveryUsersService: FakeDeliveryUsersService(
          users: <DeliveryUser>[
            _driver(uid: 'd1'),
            _driver(uid: 'd2', name: 'Trần B'),
          ],
        ),
      ),
      act: (bloc) => bloc.add(const DeliveryUsersLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.users.length, 2);
        expect(bloc.state.visibleUsers.length, 2);
      },
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'filters the drivers by name, case-insensitively',
      build: () => DeliveryBloc(
        deliveryUsersService: FakeDeliveryUsersService(),
      ),
      seed: () => DeliveryState(
        users: <DeliveryUser>[
          _driver(uid: 'd1', name: 'Nguyễn Tài xế'),
          _driver(uid: 'd2', name: 'Trần B'),
        ],
        visibleUsers: <DeliveryUser>[
          _driver(uid: 'd1', name: 'Nguyễn Tài xế'),
          _driver(uid: 'd2', name: 'Trần B'),
        ],
      ),
      act: (bloc) => bloc.add(const DeliveryUserSearchChanged('trần')),
      expect: () => [
        isA<DeliveryState>()
            .having((s) => s.query, 'query', 'trần')
            .having((s) => s.visibleUsers.length, 'visible', 1)
            .having((s) => s.visibleUsers.first.uid, 'uid', 'd2'),
      ],
    );
  });

  group('DeliveryBloc — enable / disable', () {
    blocTest<DeliveryBloc, DeliveryState>(
      'disables a driver and reports success',
      build: () => DeliveryBloc(
        deliveryUsersService: FakeDeliveryUsersService(
          users: <DeliveryUser>[_driver(uid: 'd1')],
        ),
      ),
      act: (bloc) => bloc.add(
        const DeliveryUserEnabledChanged(uid: 'd1', enabled: false),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isTrue);
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.error, isNull);
      },
    );

    test('the service receives the toggle', () async {
      final service = FakeDeliveryUsersService(
        users: <DeliveryUser>[_driver(uid: 'd1')],
      );
      final bloc = DeliveryBloc(deliveryUsersService: service)
        ..add(const DeliveryUsersLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 100));

      bloc.add(
        const DeliveryUserEnabledChanged(uid: 'd1', enabled: false),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.toggles.length, 1);
      expect(service.toggles.first['uid'], 'd1');
      expect(service.toggles.first['enabled'], isFalse);
      await bloc.close();
    });

    blocTest<DeliveryBloc, DeliveryState>(
      'surfaces a toggle failure',
      build: () {
        final service = FakeDeliveryUsersService(
          users: <DeliveryUser>[_driver(uid: 'd1')],
        );
        service.throwOnToggle = true;
        return DeliveryBloc(deliveryUsersService: service);
      },
      act: (bloc) => bloc.add(
        const DeliveryUserEnabledChanged(uid: 'd1', enabled: false),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.actionSucceeded, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });
}
