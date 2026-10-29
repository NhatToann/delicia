import 'package:flutter/foundation.dart';

/// Delivery partner details shown on the tracking bottom sheet (UC-03).
///
/// There is no backend endpoint for this yet, so the map blocs synthesise
/// instances from [_mockDrivers]. Once the realtime layer exposes the
/// assigned shipper, swap [DriverInfo.mockFor] for a real fetch — the UI
/// only depends on this class.
@immutable
class DriverInfo {
  final String name;
  final String phone;
  final double rating;
  final String plate;
  final DriverVehicle vehicle;

  const DriverInfo({
    required this.name,
    required this.phone,
    required this.rating,
    required this.plate,
    required this.vehicle,
  });

  /// Deterministic stand-in so the same order always shows the same
  /// driver across rebuilds (and across client/shipper apps).
  static const List<DriverInfo> _mockDrivers = [
    DriverInfo(
      name: 'Nguyen Van An',
      phone: '0901234567',
      rating: 4.8,
      plate: '59-X1 234.56',
      vehicle: DriverVehicle.motorbike,
    ),
    DriverInfo(
      name: 'Tran Thi Bich',
      phone: '0987654321',
      rating: 4.9,
      plate: '51-H2 891.03',
      vehicle: DriverVehicle.motorbike,
    ),
  ];

  /// Picks a stable mock driver for [orderId].
  factory DriverInfo.mockFor(String orderId) {
    if (orderId.isEmpty) return _mockDrivers.first;
    final index = orderId.codeUnits.fold<int>(0, (a, b) => a + b);
    return _mockDrivers[index % _mockDrivers.length];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DriverInfo &&
          other.name == name &&
          other.phone == phone &&
          other.plate == plate);

  @override
  int get hashCode => Object.hash(name, phone, plate);
}

/// The kind of vehicle a courier rides.
///
/// The enum carries **no user-facing copy** — the driver card renders
/// `context.l10n.driverVehicle*` so the domain layer stays free of
/// presentation concerns.
enum DriverVehicle {
  motorbike,
  car,
  bicycle,
}

/// The five checkpoints a Grab-style delivery goes through. [OrderStage]
/// maps the raw `OrderRecord.status` string onto these so the timeline can
/// be drawn without hard-coding status strings in the widget layer.
///
/// The enum carries **no user-facing copy** — the timeline widget renders
/// `context.l10n.stage*` so the domain layer stays free of presentation
/// concerns.
enum OrderStage {
  placed,
  preparing,
  dispatched,
  onTheWay,
  delivered;

  const OrderStage();

  /// Index used by the timeline widget to decide which step is active.
  int get stepIndex => OrderStage.values.indexOf(this);

  /// Maps an [OrderRecord.status] string onto a stage.
  ///
  /// The backend statuses are uppercase snake-ish labels (`PAID OUT`,
  /// `DISPATCHED`, `ON WAY`, `DELIVERED`); anything unrecognised falls
  /// back to [OrderStage.preparing] since the order exists but the courier
  /// hasn't taken over yet.
  static OrderStage fromStatus(String status) {
    switch (status.trim().toUpperCase()) {
      case 'PAID OUT':
      case 'PAID':
        return OrderStage.placed;
      case 'PREPARING':
        return OrderStage.preparing;
      case 'DISPATCHED':
        return OrderStage.dispatched;
      case 'ON WAY':
      case 'ON THE WAY':
        return OrderStage.onTheWay;
      case 'DELIVERED':
        return OrderStage.delivered;
      default:
        return OrderStage.preparing;
    }
  }
}