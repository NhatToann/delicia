import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../../data/env/environment.dart';
import '../models/hcmc_location.dart';
import '../models/lat_lng_point.dart';
import 'app_failure.dart';

/// Errors thrown by [RealtimeService] when the Firebase listener cannot
/// be opened or when a read surfaces a low-level failure.
class RealtimeServiceException extends AppFailure {
  RealtimeServiceException(super.code, [super.detail]);
}

/// Realtime position broadcast for the live order. Mirrors the legacy
/// [DeliveryPositionUpdate] shape (idOrder/latitude/longitude) so the
/// existing map blocs (UC-03) can keep using the same event class.
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

/// Realtime position broadcast for the live order.
class RealtimePositionUpdate {
  final String orderId;
  final double latitude;
  final double longitude;
  final int timestamp;

  const RealtimePositionUpdate({
    required this.orderId,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory RealtimePositionUpdate.fromMap(String orderId, Map<dynamic, dynamic> map) {
    final rawLat = double.tryParse((map['latitude'] ?? 0).toString()) ?? 0.0;
    final rawLng = double.tryParse((map['longitude'] ?? 0).toString()) ?? 0.0;
    final double lat;
    final double lng;
    if (rawLat == 0.0 && rawLng == 0.0) {
      lat = 0.0;
      lng = 0.0;
    } else if (!HcmcLocation.isInHcmc(rawLat, rawLng)) {
      final sanitized = HcmcLocation.sanitize(rawLat, rawLng);
      lat = sanitized.latitude;
      lng = sanitized.longitude;
    } else {
      lat = rawLat;
      lng = rawLng;
    }
    return RealtimePositionUpdate(
      orderId: orderId,
      latitude: lat,
      longitude: lng,
      timestamp: int.tryParse((map['timestamp'] ?? 0).toString()) ?? 0,
    );
  }
}

/// Subscription handle returned by [RealtimeService.subscribeOrder].
/// Exposes a typed stream + `cancel()` so the map blocs can release the
/// Firebase listener when they dispose.
class RealtimeSubscription {
  RealtimeSubscription({
    required this.controller,
    required this.cancelRaw,
  });

  final StreamController<RealtimePositionUpdate> controller;
  final Future<void> Function() cancelRaw;

  Stream<RealtimePositionUpdate> get stream => controller.stream;

  Future<void> cancel() async {
    await cancelRaw();
    if (!controller.isClosed) await controller.close();
  }
}

/// RealtimeService — Firebase Realtime Database backed transport used by
/// the realtime map feature (UC-03). The realtime path used by the map
/// feature is `/delicia/orders/{orderId}/shipperLocation`.
///
/// Why Firebase RTDB instead of a Socket.io server?
/// - No extra server to deploy/maintain (we already have RTDB).
/// - Free tier covers the expected traffic for a class project.
/// - Built-in `onValue` listener + `set` write — simpler than rolling
///   our own socket protocol.
///
/// Tests can inject a [FirebaseDatabase] via the `database` parameter or
/// implement their own transport. The current constructor signature is
/// purposely minimal so the call sites in the map blocs don't change.
class RealtimeService {
  RealtimeService({FirebaseDatabase? database})
      : _database = database ?? _defaultDatabase();

  final FirebaseDatabase? _database;

  static FirebaseDatabase? _defaultDatabase() {
    try {
      return FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL: Environment.firebaseDatabaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  DatabaseReference? get _ordersRef =>
      _database?.ref('${Environment.dbRoot}/orders');

  /// Publishes the driver's current location to
  /// `/delicia/orders/{orderId}/shipperLocation`.
  Future<void> publishPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw RealtimeServiceException(AppFailureCodes.firebaseNotInitialised);
    }
    final point = (latitude == 0.0 && longitude == 0.0)
        ? const LatLngPoint(latitude: 0, longitude: 0)
        : HcmcLocation.sanitize(latitude, longitude);
    try {
      await ref.child(orderId).child('shipperLocation').set({
        'latitude': point.latitude,
        'longitude': point.longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw RealtimeServiceException(AppFailureCodes.realtimePublish, '$e');
    }
  }

  /// Publishes the **client's own** live position to
  /// `/delicia/orders/{orderId}/clientLocation`.
  ///
  /// This is the mirror of [publishPosition]: while the driver publishes
  /// where *they* are, the client publishes where *they* are so the
  /// delivery side can render the destination on its own map.  Both
  /// channels live under the same order document, so they are garbage
  /// collected together when the order is removed.
  Future<void> publishClientPosition({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    final ref = _ordersRef;
    if (ref == null) {
      throw RealtimeServiceException(
        'Firebase Database not initialized. Call Firebase.initializeApp() first.',
      );
    }
    try {
      await ref.child(orderId).child('clientLocation').set({
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw RealtimeServiceException('Failed to publish client position: $e');
    }
  }

  /// Subscribes to the driver's position updates for [orderId]. The first
  /// event is the current value (if any) — Firebase `onValue` always
  /// fires once on attach.
  RealtimeSubscription subscribeOrder(String orderId) {
    final ref = _ordersRef;
    final controller = StreamController<RealtimePositionUpdate>.broadcast();
    if (ref == null) {
      // Without Firebase the controller is closed immediately so callers
      // get a deterministic empty stream.
      Future.microtask(() {
        if (!controller.isClosed) controller.close();
      });
      return RealtimeSubscription(
        controller: controller,
        cancelRaw: () async {},
      );
    }
    final query = ref.child(orderId).child('shipperLocation');
    final listener = query.onValue.listen(
      (event) {
        final value = event.snapshot.value;
        if (value is! Map) return;
        try {
          controller.add(
            RealtimePositionUpdate.fromMap(
              orderId,
              Map<dynamic, dynamic>.from(value),
            ),
          );
        } catch (_) {
          // Drop malformed payloads silently.
        }
      },
      onError: controller.addError,
      cancelOnError: false,
    );
    return RealtimeSubscription(
      controller: controller,
      cancelRaw: () async {
        await listener.cancel();
      },
    );
  }

  /// Subscribes to the **client's** live position for [orderId].
  ///
  /// This is the counterpart of [subscribeOrder]: the delivery driver
  /// listens here to render the destination marker, so the client has to
  /// publish its own GPS coordinates to
  /// `/delicia/orders/{orderId}/clientLocation`.
  RealtimeSubscription subscribeClientLocation(String orderId) {
    final ref = _ordersRef;
    final controller = StreamController<RealtimePositionUpdate>.broadcast();
    if (ref == null) {
      Future.microtask(() {
        if (!controller.isClosed) controller.close();
      });
      return RealtimeSubscription(
        controller: controller,
        cancelRaw: () async {},
      );
    }
    final query = ref.child(orderId).child('clientLocation');
    final listener = query.onValue.listen(
      (event) {
        final value = event.snapshot.value;
        if (value is! Map) return;
        try {
          controller.add(
            RealtimePositionUpdate.fromMap(
              orderId,
              Map<dynamic, dynamic>.from(value),
            ),
          );
        } catch (_) {
          // Drop malformed payloads silently.
        }
      },
      onError: controller.addError,
      cancelOnError: false,
    );
    return RealtimeSubscription(
      controller: controller,
      cancelRaw: () async {
        await listener.cancel();
      },
    );
  }
}
