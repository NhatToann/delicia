// UC-09 — DeliveryBloc tests.
//
// Covers:
//   * the realtime driver feed,
//   * the search filter,
//   * the enable / disable toggle (the happy path and the failure).

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/delivery/delivery_bloc.dart';
import 'package:delicia/domain/models/delivery_user.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/domain/services/app_failure.dart';
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

  group('DeliveryBloc — create / delete', () {
    blocTest<DeliveryBloc, DeliveryState>(
      'creates a driver and reports success',
      build: () => DeliveryBloc(deliveryUsersService: FakeDeliveryUsersService()),
      act: (bloc) => bloc.add(
        const DeliveryUserCreated(
          email: 'tai.xe@delicia.vn',
          password: '123456',
          firstName: 'Nguyễn',
          lastName: 'Tài xế',
          phone: '0900000000',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.driverCreated, isTrue);
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.error, isNull);
      },
    );

    test('the service receives the new driver', () async {
      final service = FakeDeliveryUsersService();
      final bloc = DeliveryBloc(deliveryUsersService: service);

      bloc.add(
        const DeliveryUserCreated(
          email: 'tai.xe@delicia.vn',
          password: '123456',
          firstName: 'Nguyễn',
          lastName: 'Tài xế',
          phone: '0900000000',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.created.length, 1);
      expect(service.created.first['email'], 'tai.xe@delicia.vn');
      expect(service.created.first['firstName'], 'Nguyễn');
      await bloc.close();
    });

    blocTest<DeliveryBloc, DeliveryState>(
      'surfaces a create failure',
      build: () {
        final service = FakeDeliveryUsersService();
        service.throwOnCreate = AdminOrdersServiceException(
          AppFailureCodes.deliveryCreate,
          'boom',
        );
        return DeliveryBloc(deliveryUsersService: service);
      },
      act: (bloc) => bloc.add(
        const DeliveryUserCreated(
          email: 'tai.xe@delicia.vn',
          password: '123456',
          firstName: 'Nguyễn',
          lastName: 'Tài xế',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.driverCreated, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );

    blocTest<DeliveryBloc, DeliveryState>(
      'deletes a driver and reports the name',
      build: () => DeliveryBloc(deliveryUsersService: FakeDeliveryUsersService()),
      act: (bloc) => bloc.add(
        const DeliveryUserDeleted(
          uid: 'd1',
          email: 'tai.xe@delicia.vn',
          name: 'Nguyễn Tài xế',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.deletedDriverName, 'Nguyễn Tài xế');
        expect(bloc.state.isSubmitting, isFalse);
        expect(bloc.state.error, isNull);
      },
    );

    test('the service receives the deletion', () async {
      final service = FakeDeliveryUsersService();
      final bloc = DeliveryBloc(deliveryUsersService: service);

      bloc.add(
        const DeliveryUserDeleted(
          uid: 'd1',
          email: 'tai.xe@delicia.vn',
          name: 'Nguyễn Tài xế',
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(service.deleted.length, 1);
      expect(service.deleted.first['uid'], 'd1');
      await bloc.close();
    });

    blocTest<DeliveryBloc, DeliveryState>(
      'surfaces a delete failure',
      build: () {
        final service = FakeDeliveryUsersService();
        service.throwOnDelete = AdminOrdersServiceException(
          AppFailureCodes.deliveryDelete,
          'boom',
        );
        return DeliveryBloc(deliveryUsersService: service);
      },
      act: (bloc) => bloc.add(
        const DeliveryUserDeleted(
          uid: 'd1',
          email: 'tai.xe@delicia.vn',
          name: 'Nguyễn Tài xế',
        ),
      ),
      wait: const Duration(milliseconds: 50),
      verify: (bloc) {
        expect(bloc.state.deletedDriverName, isNull);
        expect(bloc.state.error, isNotNull);
      },
    );
  });
}
