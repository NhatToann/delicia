// UC-03 — SocketService unit tests. We inject a fake transport so the
// tests don't touch the network.

import 'dart:async';

import 'package:delicia/domain/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTransport implements SocketTransport {
  bool connected = false;
  final Map<String, StreamController<dynamic>> _onStreams = {};
  final List<({String event, Map<String, dynamic> data})> emits = [];
  int connectCalls = 0;
  int disconnectCalls = 0;

  @override
  bool get isConnected => connected;

  @override
  void connect() {
    connectCalls++;
    connected = true;
  }

  @override
  void disconnect() {
    disconnectCalls++;
    connected = false;
  }

  @override
  void emit(String event, Map<String, dynamic> data) {
    emits.add((event: event, data: data));
  }

  @override
  Stream<dynamic> on(String event) {
    final controller = _onStreams.putIfAbsent(
      event,
      () => StreamController<dynamic>.broadcast(),
    );
    return controller.stream;
  }

  void push(String event, dynamic data) {
    final controller = _onStreams[event];
    if (controller != null && !controller.isClosed) {
      controller.add(data);
    }
  }
}

void main() {
  group('SocketService', () {
    late _FakeTransport transport;
    late SocketService service;

    setUp(() {
      transport = _FakeTransport();
      service = SocketService(transport: transport);
    });

    tearDown(() async {
      await service.disconnect();
    });

    test('connect() calls transport.connect and toggles flag', () async {
      await service.connect();
      expect(transport.connectCalls, 1);
      expect(service.isConnected, isTrue);
    });

    test('connect() is idempotent — second call is a no-op', () async {
      await service.connect();
      await service.connect();
      expect(transport.connectCalls, 1);
    });

    test('joinOrder emits a join event', () async {
      await service.joinOrder('order-1');
      expect(transport.emits, hasLength(1));
      expect(transport.emits.first.event, 'join');
      expect(transport.emits.first.data['orderId'], 'order-1');
    });

    test('emitPosition emits a position event with idOrder/lat/lng',
        () async {
      await service.emitPosition(
        orderId: 'o1',
        latitude: 10.5,
        longitude: 106.7,
      );
      expect(transport.emits, hasLength(1));
      expect(transport.emits.first.event, 'position');
      expect(transport.emits.first.data, {
        'idOrder': 'o1',
        'latitude': 10.5,
        'longitude': 106.7,
      });
    });

    test('onPositionUpdate parses payloads and yields typed updates',
        () async {
      await service.connect();
      final received = <DeliveryPositionUpdate>[];
      final sub = service.onPositionUpdate('o1');
      final streamSub = sub.stream.listen(received.add);
      transport.push('position/o1', {
        'idOrder': 'o1',
        'latitude': 10.5,
        'longitude': 106.7,
      });
      await Future<void>.delayed(Duration.zero);
      await streamSub.cancel();
      expect(received, hasLength(1));
      expect(received.first.orderId, 'o1');
      expect(received.first.latitude, 10.5);
      expect(received.first.longitude, 106.7);
    });

    test('onPositionUpdate drops malformed payloads', () async {
      await service.connect();
      final received = <DeliveryPositionUpdate>[];
      final sub = service.onPositionUpdate('o1');
      final streamSub = sub.stream.listen(received.add);
      transport.push('position/o1', 'not a map');
      await Future<void>.delayed(Duration.zero);
      await streamSub.cancel();
      expect(received, isEmpty);
    });

    test('disconnect cancels all listeners and disconnects transport',
        () async {
      await service.connect();
      service.onPositionUpdate('o1');
      service.onPositionUpdate('o2');
      await service.disconnect();
      expect(transport.disconnectCalls, 1);
      expect(service.isConnected, isFalse);
    });
  });
}