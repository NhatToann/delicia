import 'order_item.dart';

/// Top-level order document (UC-04).
///
/// Stored under `/delicia/orders/{orderId}` in the Realtime Database.
/// Mirrors the original Frave payload so the existing admin tabs (PAID OUT
/// / DISPATCHED / ON WAY / DELIVERED) can read the same shape.
class OrderRecord {
  final String id;
  final String clientId;
  final String addressId;
  final String street;
  final String reference;
  final double latitude;
  final double longitude;
  final String paymentMethod;
  final double amount;
  final String status;
  final List<OrderItem> products;
  final DateTime createdAt;

  const OrderRecord({
    required this.id,
    required this.clientId,
    required this.addressId,
    required this.street,
    required this.reference,
    required this.latitude,
    required this.longitude,
    required this.paymentMethod,
    required this.amount,
    required this.status,
    required this.products,
    required this.createdAt,
  });

  /// Default "PAID OUT" — the initial status set by the client at checkout.
  static const String statusPaidOut = 'PAID OUT';
  static const String statusDispatched = 'DISPATCHED';
  static const String statusOnWay = 'ON WAY';
  static const String statusDelivered = 'DELIVERED';

  /// Whether the client is allowed to open the live tracking map. Live
  /// tracking is only useful once a driver has been assigned and is on
  /// the way. Orders that are still PAID OUT or DELIVERED don't have a
  /// moving courier, so the button is disabled.
  bool get canTrackDelivery =>
      status == statusOnWay || status == statusDispatched;

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'addressId': addressId,
        'street': street,
        'reference': reference,
        'latitude': latitude,
        'longitude': longitude,
        'paymentMethod': paymentMethod,
        'amount': amount,
        'status': status,
        'products': products.map((p) => p.toMap()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory OrderRecord.fromMap(String id, Map<dynamic, dynamic> map) {
    final raw = map['products'];
    final items = <OrderItem>[];
    if (raw is List) {
      for (final entry in raw) {
        if (entry is Map) {
          items.add(OrderItem.fromMap(Map<dynamic, dynamic>.from(entry)));
        }
      }
    }
    return OrderRecord(
      id: id,
      clientId: (map['clientId'] ?? '').toString(),
      addressId: (map['addressId'] ?? '').toString(),
      street: (map['street'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      latitude:
          double.tryParse((map['latitude'] ?? '0').toString()) ?? 0.0,
      longitude:
          double.tryParse((map['longitude'] ?? '0').toString()) ?? 0.0,
      paymentMethod: (map['paymentMethod'] ?? 'CASH PAYMENT').toString(),
      amount: double.tryParse((map['amount'] ?? 0).toString()) ?? 0.0,
      status: (map['status'] ?? statusPaidOut).toString(),
      products: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse((map['createdAt'] ?? 0).toString()) ?? 0,
      ),
    );
  }
}