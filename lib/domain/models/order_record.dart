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
  final String? deliveryId;
  final String? deliveryName;
  final String? deliveryPhoto;
  final String? receiverPhone;
  final String? receiverName;
  final List<String> rejectedBy;

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
    this.deliveryId,
    this.deliveryName,
    this.deliveryPhoto,
    this.receiverPhone,
    this.receiverName,
    this.rejectedBy = const [],
  });

  /// Default "PAID OUT" — the initial status set by the client at checkout.
  static const String statusPaidOut = 'PAID OUT';
  static const String statusDispatched = 'DISPATCHED';
  static const String statusOnWay = 'ON WAY';
  static const String statusDelivered = 'DELIVERED';

  /// Set when the client cancels the order before the restaurant accepts
  /// it. Surfaces on the order history under the Cancelled filter.
  static const String statusCancelled = 'CANCELLED';

  /// Whether the client is allowed to open the live tracking map. Live
  /// tracking is only useful once a driver has been assigned and is on
  /// the way. Orders that are still PAID OUT / DELIVERED / CANCELLED
  /// don't have a moving courier, so the button is disabled.
  bool get canTrackDelivery =>
      status == statusOnWay || status == statusDispatched;

  /// Whether the cancellation flow is still available (the order hasn't
  /// reached the courier yet). Cancel UX lands in a later use-case; until
  /// then the UI just uses this flag to disable the button.
  bool get canCancel =>
      status == statusPaidOut;

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
        if (deliveryId != null) 'deliveryId': deliveryId,
        if (deliveryName != null) 'deliveryName': deliveryName,
        if (deliveryPhoto != null) 'deliveryPhoto': deliveryPhoto,
        if (receiverPhone != null) 'receiverPhone': receiverPhone,
        if (receiverName != null) 'receiverName': receiverName,
        if (rejectedBy.isNotEmpty)
          'rejectedBy': {for (final uid in rejectedBy) uid: true},
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
    final rawRejected = map['rejectedBy'];
    final rejectedList = <String>[];
    if (rawRejected is Map) {
      for (final entry in rawRejected.entries) {
        if (entry.value == true || entry.value == 1 || entry.value == 'true') {
          rejectedList.add(entry.key.toString());
        }
      }
    } else if (rawRejected is List) {
      for (final item in rawRejected) {
        if (item != null) rejectedList.add(item.toString());
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
      amount: (() {
        var a = double.tryParse((map['amount'] ?? 0).toString()) ?? 0.0;
        if (a >= 1000) a = a / 10000.0;
        return a;
      })(),
      status: (map['status'] ?? statusPaidOut).toString(),
      products: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse((map['createdAt'] ?? 0).toString()) ?? 0,
      ),
      deliveryId: map['deliveryId']?.toString(),
      deliveryName: map['deliveryName']?.toString(),
      deliveryPhoto: map['deliveryPhoto']?.toString(),
      receiverPhone: map['receiverPhone']?.toString(),
      receiverName: map['receiverName']?.toString(),
      rejectedBy: rejectedList,
    );
  }

  OrderRecord copyWith({
    String? id,
    String? clientId,
    String? addressId,
    String? street,
    String? reference,
    double? latitude,
    double? longitude,
    String? paymentMethod,
    double? amount,
    String? status,
    List<OrderItem>? products,
    DateTime? createdAt,
    String? deliveryId,
    String? deliveryName,
    String? deliveryPhoto,
    String? receiverPhone,
    String? receiverName,
    List<String>? rejectedBy,
  }) {
    return OrderRecord(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      addressId: addressId ?? this.addressId,
      street: street ?? this.street,
      reference: reference ?? this.reference,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      products: products ?? this.products,
      createdAt: createdAt ?? this.createdAt,
      deliveryId: deliveryId ?? this.deliveryId,
      deliveryName: deliveryName ?? this.deliveryName,
      deliveryPhoto: deliveryPhoto ?? this.deliveryPhoto,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverName: receiverName ?? this.receiverName,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }
}
