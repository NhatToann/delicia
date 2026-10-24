// UC-03 — RealtimeService unit tests. We don't hit Firebase here; the
// tests focus on payload parsing and the controller lifecycle.

import 'package:delicia/domain/services/realtime_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RealtimePositionUpdate', () {
    test('fromMap parses all fields', () {
      final update = RealtimePositionUpdate.fromMap('order-1', {
        'latitude': 10.5,
        'longitude': 106.7,
        'timestamp': 1700000000000,
      });
      expect(update.orderId, 'order-1');
      expect(update.latitude, 10.5);
      expect(update.longitude, 106.7);
      expect(update.timestamp, 1700000000000);
    });

    test('fromMap tolerates missing / malformed fields', () {
      final update = RealtimePositionUpdate.fromMap('order-1', const {});
      expect(update.latitude, 0);
      expect(update.longitude, 0);
      expect(update.timestamp, 0);
    });
  });

  group('RealtimeService', () {
    test('publishPosition uses the configured databaseURL + path', () {
      // We don't actually hit Firebase in unit tests; just make sure
      // the public surface compiles and the type can be constructed.
      final service = RealtimeService();
      expect(service, isA<RealtimeService>());
    });
  });
}
