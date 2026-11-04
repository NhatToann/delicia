import 'package:delicia/domain/models/delivery_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeliveryStatus State Machine Tests (UC-11)', () {
    test('Valid sequential happy-path transitions succeed', () {
      expect(DeliveryStatus.pending.canTransitionTo(DeliveryStatus.accepted), isTrue);
      expect(DeliveryStatus.accepted.canTransitionTo(DeliveryStatus.pickedUp), isTrue);
      expect(DeliveryStatus.pickedUp.canTransitionTo(DeliveryStatus.onTheWay), isTrue);
      expect(DeliveryStatus.onTheWay.canTransitionTo(DeliveryStatus.delivered), isTrue);

      // transitionTo returns the next state when valid
      expect(
        DeliveryStatus.pending.transitionTo(DeliveryStatus.accepted),
        equals(DeliveryStatus.accepted),
      );
      expect(
        DeliveryStatus.accepted.transitionTo(DeliveryStatus.pickedUp),
        equals(DeliveryStatus.pickedUp),
      );
      expect(
        DeliveryStatus.pickedUp.transitionTo(DeliveryStatus.onTheWay),
        equals(DeliveryStatus.onTheWay),
      );
      expect(
        DeliveryStatus.onTheWay.transitionTo(DeliveryStatus.delivered),
        equals(DeliveryStatus.delivered),
      );
    });

    test('Cancellation from non-terminal states is allowed', () {
      expect(DeliveryStatus.pending.canTransitionTo(DeliveryStatus.cancelled), isTrue);
      expect(DeliveryStatus.accepted.canTransitionTo(DeliveryStatus.cancelled), isTrue);
      expect(DeliveryStatus.pickedUp.canTransitionTo(DeliveryStatus.cancelled), isTrue);
      expect(DeliveryStatus.onTheWay.canTransitionTo(DeliveryStatus.cancelled), isTrue);

      expect(
        DeliveryStatus.pending.transitionTo(DeliveryStatus.cancelled),
        equals(DeliveryStatus.cancelled),
      );
    });

    test('Invalid transitions are rejected and throw StateError', () {
      // Skipping steps is invalid
      expect(DeliveryStatus.pending.canTransitionTo(DeliveryStatus.delivered), isFalse);
      expect(
        () => DeliveryStatus.pending.transitionTo(DeliveryStatus.delivered),
        throwsA(isA<StateError>()),
      );

      expect(DeliveryStatus.pending.canTransitionTo(DeliveryStatus.pickedUp), isFalse);
      expect(
        () => DeliveryStatus.pending.transitionTo(DeliveryStatus.pickedUp),
        throwsA(isA<StateError>()),
      );

      // Backwards transitions are invalid
      expect(DeliveryStatus.delivered.canTransitionTo(DeliveryStatus.pending), isFalse);
      expect(
        () => DeliveryStatus.delivered.transitionTo(DeliveryStatus.pending),
        throwsA(isA<StateError>()),
      );

      expect(DeliveryStatus.onTheWay.canTransitionTo(DeliveryStatus.accepted), isFalse);
      expect(
        () => DeliveryStatus.onTheWay.transitionTo(DeliveryStatus.accepted),
        throwsA(isA<StateError>()),
      );

      // Terminal states cannot transition to anything
      expect(DeliveryStatus.delivered.canTransitionTo(DeliveryStatus.cancelled), isFalse);
      expect(
        () => DeliveryStatus.delivered.transitionTo(DeliveryStatus.cancelled),
        throwsA(isA<StateError>()),
      );

      expect(DeliveryStatus.cancelled.canTransitionTo(DeliveryStatus.accepted), isFalse);
      expect(
        () => DeliveryStatus.cancelled.transitionTo(DeliveryStatus.accepted),
        throwsA(isA<StateError>()),
      );
    });

    test('nextStep returns expected sequential transition', () {
      expect(DeliveryStatus.pending.nextStep, equals(DeliveryStatus.accepted));
      expect(DeliveryStatus.accepted.nextStep, equals(DeliveryStatus.pickedUp));
      expect(DeliveryStatus.pickedUp.nextStep, equals(DeliveryStatus.onTheWay));
      expect(DeliveryStatus.onTheWay.nextStep, equals(DeliveryStatus.delivered));
      expect(DeliveryStatus.delivered.nextStep, isNull);
      expect(DeliveryStatus.cancelled.nextStep, isNull);
    });

    test('fromString parses various status formats correctly', () {
      expect(DeliveryStatus.fromString('PAID OUT'), equals(DeliveryStatus.pending));
      expect(DeliveryStatus.fromString('PENDING'), equals(DeliveryStatus.pending));
      expect(DeliveryStatus.fromString('DISPATCHED'), equals(DeliveryStatus.accepted));
      expect(DeliveryStatus.fromString('ACCEPTED'), equals(DeliveryStatus.accepted));
      expect(DeliveryStatus.fromString('PICKED UP'), equals(DeliveryStatus.pickedUp));
      expect(DeliveryStatus.fromString('ON WAY'), equals(DeliveryStatus.onTheWay));
      expect(DeliveryStatus.fromString('ON_THE_WAY'), equals(DeliveryStatus.onTheWay));
      expect(DeliveryStatus.fromString('DELIVERED'), equals(DeliveryStatus.delivered));
      expect(DeliveryStatus.fromString('CANCELLED'), equals(DeliveryStatus.cancelled));
      expect(DeliveryStatus.fromString('REJECTED'), equals(DeliveryStatus.cancelled));
      expect(DeliveryStatus.fromString('unknown_status'), equals(DeliveryStatus.pending));
    });

    test('labels and dbStatus map accurately', () {
      expect(DeliveryStatus.pending.label, equals('Pending'));
      expect(DeliveryStatus.pending.dbStatus, equals('PAID OUT'));
      expect(DeliveryStatus.delivered.label, equals('Delivered'));
      expect(DeliveryStatus.delivered.dbStatus, equals('DELIVERED'));
    });
  });
}
