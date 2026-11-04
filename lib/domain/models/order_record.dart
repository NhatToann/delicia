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
  final String? deliveryPhoto;
  final String? receiverPhone;
  final String? receiverName;
  final List<String> rejectedBy;

  /// Uid of the delivery driver assigned to this order (UC-09).
  ///
  /// Empty until the admin assigns a courier — a freshly paid order has
  /// nobody carrying it yet.
  ///
  /// This is the SINGLE source of truth for "who is delivering this order".
  /// Older rows were written by the driver flow under the legacy key
  /// `deliveryId`; [OrderRecord.fromMap] falls back to that key so no data
  /// migration is required, and every writer now uses `deliveryUserId`.
  final String deliveryUserId;

  /// Display name of the assigned driver, denormalised so the admin
  /// order list does not need a second lookup per row.
  final String deliveryUserName;

  /// Display name of the customer who placed the order.
  ///
  /// Denormalised at checkout time for the same reason as
  /// [deliveryUserName]: the admin console has to show *who* ordered
  /// without a second lookup per row. Orders created before this field
  /// existed keep an empty value — the admin UI falls back to the
  /// customer id then.
  final String clientName;

  /// Contact email of the customer who placed the order.
  final String clientEmail;

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
    this.deliveryUserId = '',
    this.deliveryUserName = '',
    this.clientName = '',
    this.clientEmail = '',
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

  /// The kitchen has started preparing the order (UC-09).
  ///
  /// Only the admin console writes this status — it sits between
  /// [statusPaidOut] and [statusDispatched].
  static const String statusPreparing = 'PREPARING';

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

  /// Whether a delivery driver may be assigned to this order (UC-09).
  ///
  /// Only a paid order that has not left the kitchen yet can still get
  /// a courier — once it is on the way, the courier is fixed.
  bool get canAssignDelivery =>
      status == statusPaidOut || status == statusPreparing;

  /// Whether the admin may move the order to the "preparing" stage.
  bool get canStartPreparing => status == statusPaidOut;

  /// Whether the admin may mark the order as delivered.
  bool get canComplete => status == statusDispatched || status == statusOnWay;

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
        if (deliveryUserId.isNotEmpty) 'deliveryUserId': deliveryUserId,
        if (deliveryUserName.isNotEmpty) 'deliveryUserName': deliveryUserName,
        if (clientName.isNotEmpty) 'clientName': clientName,
        if (clientEmail.isNotEmpty) 'clientEmail': clientEmail,
        if (deliveryPhoto != null) 'deliveryPhoto': deliveryPhoto,
        if (receiverPhone != null) 'receiverPhone': receiverPhone,
        if (receiverName != null) 'receiverName': receiverName,
        if (rejectedBy.isNotEmpty)
          'rejectedBy': {for (final uid in rejectedBy) uid: true},
      };

  /// Reads the assigned courier uid.
  ///
  /// `deliveryUserId` is the canonical key. `deliveryId` is the legacy key
  /// written by the driver flow before the two flows were unified — reading
  /// it as a fallback keeps historical rows assignable without a data
  /// migration.
  static String _readCourierUid(Map<dynamic, dynamic> map) {
    final canonical = (map['deliveryUserId'] ?? '').toString().trim();
    if (canonical.isNotEmpty) return canonical;
    return (map['deliveryId'] ?? '').toString().trim();
  }

  /// Reads the assigned courier display name (same fallback as the uid).
  static String _readCourierName(Map<dynamic, dynamic> map) {
    final canonical = (map['deliveryUserName'] ?? '').toString().trim();
    if (canonical.isNotEmpty) return canonical;
    return (map['deliveryName'] ?? '').toString().trim();
  }

  factory OrderRecord.fromMap(String id, Map<dynamic, dynamic> map) {    final raw = map['products'];
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
      amount: double.tryParse((map['amount'] ?? 0).toString()) ?? 0.0,
      status: (map['status'] ?? statusPaidOut).toString(),
      products: items,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        int.tryParse((map['createdAt'] ?? 0).toString()) ?? 0,
      ),
      deliveryUserId: _readCourierUid(map),
      deliveryUserName: _readCourierName(map),
      clientName: (map['clientName'] ?? '').toString(),
      clientEmail: (map['clientEmail'] ?? '').toString(),
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
    String? deliveryUserId,
    String? deliveryUserName,
    String? clientName,
    String? clientEmail,
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
      deliveryUserId: deliveryUserId ?? this.deliveryUserId,
      deliveryUserName: deliveryUserName ?? this.deliveryUserName,
      clientName: clientName ?? this.clientName,
      clientEmail: clientEmail ?? this.clientEmail,
      deliveryPhoto: deliveryPhoto ?? this.deliveryPhoto,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverName: receiverName ?? this.receiverName,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }
}
