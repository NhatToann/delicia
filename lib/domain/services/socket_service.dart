import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart' as io;

// NOTE: The previous version pulled `Environment.socketEndpoint` for the
// realtime channel. The socket.io server is a Node.js side-channel that is
// not part of the Firebase Realtime Database. UC-03 will re-introduce the
// endpoint constant once the socket server is deployed. For now, callers
// must pass an explicit `endpoint` to [DefaultSocketTransport] or supply
// a custom [SocketTransport] (used by tests).

/// Errors thrown by [SocketService] when the connection cannot be opened or
/// when an emit/listener call surfaces a low-level failure.
class SocketServiceException implements Exception {
  final String message;
  SocketServiceException(this.message);
  @override
  String toString() => message;
}

/// One realtime position update broadcast by the delivery app.
class DeliveryPositionUpdate {
  final String orderId;
  final double latitude;
  final double longitude;

  const DeliveryPositionUpdate({
    required this.orderId,
    required this.latitude,
    required this.longitude,
  });

  factory DeliveryPositionUpdate.fromMap(Map<dynamic, dynamic> map) {
    return DeliveryPositionUpdate(
      orderId: (map['idOrder'] ?? map['orderId'] ?? '').toString(),
      latitude: double.tryParse((map['latitude'] ?? 0).toString()) ?? 0.0,
      longitude: double.tryParse((map['longitude'] ?? 0).toString()) ?? 0.0,
    );
  }
}

/// Abstract transport so unit tests can inject a fake transport without
/// touching the real socket.
abstract class SocketTransport {
  void connect();
  void disconnect();
  void emit(String event, Map<String, dynamic> data);
  Stream<dynamic> on(String event);
  bool get isConnected;
}

/// Default transport built on top of the official
/// `socket_io_client` package.
///
/// The endpoint must be supplied explicitly; there is no default because
/// the realtime map server is deployed independently (UC-03) and lives
/// outside of `Environment`.
class DefaultSocketTransport implements SocketTransport {
  DefaultSocketTransport({required this.endpoint});

  final String endpoint;
  io.Socket? _socket;

  @override
  bool get isConnected => _socket?.connected ?? false;

  @override
  void connect() {
    try {
      _socket = io.io(
        endpoint,
        io.OptionBuilder()
            .setTransports(['websocket'])
            .disableAutoConnect()
            .build(),
      );
      _socket!.connect();
    } catch (e) {
      throw SocketServiceException('connect() failed: $e');
    }
  }

  @override
  void disconnect() {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.disconnect();
      socket.dispose();
    } finally {
      _socket = null;
    }
  }

  @override
  void emit(String event, Map<String, dynamic> data) {
    final socket = _socket;
    if (socket == null) {
      throw SocketServiceException('emit($event) called before connect()');
    }
    socket.emit(event, data);
  }

  @override
  Stream<dynamic> on(String event) {
    final socket = _socket;
    if (socket == null) {
      throw SocketServiceException('on($event) called before connect()');
    }
    final controller = StreamController<dynamic>.broadcast();
    socket.on(event, (data) {
      if (!controller.isClosed) controller.add(data);
    });
    controller.onCancel = () => controller.close();
    return controller.stream;
  }
}

/// Subscription handle returned by [SocketService.onPositionUpdate].
/// Provides a typed stream of updates plus a `cancel()` that cleans up the
/// inner socket.io listener.
class PositionSubscription {
  PositionSubscription._({
    required this.subscription,
    required this.controller,
  });

  final StreamSubscription<dynamic> subscription;
  final StreamController<DeliveryPositionUpdate> controller;

  Stream<DeliveryPositionUpdate> get stream => controller.stream;

  Future<void> cancel() async {
    await subscription.cancel();
    if (!controller.isClosed) await controller.close();
  }
}

/// SocketService — wraps the connection lifecycle for the realtime map
/// feature (UC-03). Exposes `connect`, `disconnect`, `joinOrder`,
/// `emitPosition`, and `onPositionUpdate` so the BLoCs don't have to know
/// about the underlying transport.
///
/// Tests can substitute [SocketTransport] via the constructor to avoid
/// hitting the network.
class SocketService {
  SocketService({SocketTransport? transport})
      : _transport = transport ?? DefaultSocketTransport(
          endpoint: 'wss://example.invalid/socket',
        );

  final SocketTransport _transport;
  bool _connected = false;
  final Map<String, PositionSubscription> _listeners = {};

  /// Opens the underlying socket if it is not already connected.
  Future<void> connect() async {
    if (_connected) return;
    try {
      _transport.connect();
      _connected = _transport.isConnected;
    } catch (e) {
      _connected = false;
      rethrow;
    }
  }

  /// Closes the underlying socket and cancels all listeners.
  Future<void> disconnect() async {
    if (!_connected) return;
    for (final sub in _listeners.values) {
      await sub.cancel();
    }
    _listeners.clear();
    _transport.disconnect();
    _connected = false;
  }

  /// Tells the server we're watching [orderId]. Auto-connects on first use.
  Future<void> joinOrder(String orderId) async {
    await connect();
    _transport.emit('join', {'orderId': orderId});
  }

  /// Broadcasts a position update from the delivery app.
  Future<void> emitPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    await connect();
    _transport.emit('position', {
      'idOrder': orderId,
      'latitude': latitude,
      'longitude': longitude,
    });
  }

  /// Subscribes to position updates for [orderId]. Returns the
  /// subscription so the caller can cancel it on dispose.
  PositionSubscription onPositionUpdate(String orderId) {
    final event = 'position/$orderId';
    final controller =
        StreamController<DeliveryPositionUpdate>.broadcast();
    final sub = _transport.on(event).listen(
      (data) {
        if (data is Map) {
          try {
            controller.add(
              DeliveryPositionUpdate.fromMap(
                Map<dynamic, dynamic>.from(data),
              ),
            );
          } catch (_) {
            // Drop malformed payloads silently — the server is the source
            // of truth and will retry the next tick.
          }
        }
      },
      onError: controller.addError,
    );
    final wrapped = PositionSubscription._(
      subscription: sub,
      controller: controller,
    );
    _listeners[event] = wrapped;
    return wrapped;
  }

  /// Removes a previously registered listener. Safe to call multiple times.
  Future<void> removeListener(String orderId) async {
    final sub = _listeners.remove('position/$orderId');
    await sub?.cancel();
  }

  bool get isConnected => _connected && _transport.isConnected;
}