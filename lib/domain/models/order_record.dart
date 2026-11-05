import 'order_item.dart';
import 'price_breakdown.dart';

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

  /// The itemised money breakdown, persisted at checkout.
  ///
  /// Checkout is **cash on delivery**: the courier physically collects the
  /// money at the door. The breakdown is therefore the contract between
  /// the three sides — it says exactly how much the customer was quoted,
  /// how much of it is tax, how much is the courier's fee and how much
  /// belongs to the restaurant. Without it the courier has to re-derive
  /// the number from a single `amount`, and the restaurant's revenue
  /// number silently includes tax and the courier's cut.
  ///
  /// Null for orders written before this field existed.
  final PriceBreakdown? quote;

  /// Road distance (km) between the restaurant and the drop-off point.
  ///
  /// Persisted so the courier's pay is derived from the *same* number the
  /// customer was quoted — recomputing it from the order coordinates
  /// gives a different (straight-line) distance.
  final double distanceKm;

  /// Whether the courier has collected the cash for this order.
  ///
  /// This is the only record of the money movement in a cash-on-delivery
  /// app: without it the restaurant cannot tell the difference between
  /// cash it has and cash it is owed.
  final bool cashCollected;

  /// When the cash was collected (ms since epoch). Zero when not yet.
  final int cashCollectedAt;

  /// How much cash the courier actually collected, in whole VND.
  ///
  /// Zero means "not recorded" — which is also the correct value for an
  /// order that was free (or for a row written before this field existed).
  /// The number is only meaningful together with [cashCollected]: a
  /// courier who reports a *different* figure than the customer was
  /// quoted is the signal that something went wrong at the door.
  final int collectedAmountVnd;

  /// Lifecycle timestamps (ms since epoch).
  ///
  /// An order walks through four moments: the customer paid, the kitchen
  /// dispatched it, the courier picked it up, and it was delivered. Only
  /// [createdAt] used to be persisted, which made "orders delivered
  /// today" and "average delivery time" impossible to compute — the
  /// dashboard had to guess from a single timestamp.
  ///
  /// Zero means "has not happened yet".
  final int placedAt;
  final int dispatchedAt;
  final int onWayAt;
  final int deliveredAt;

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
    this.quote,
    this.distanceKm = 0.0,
    this.cashCollected = false,
    this.cashCollectedAt = 0,
    this.collectedAmountVnd = 0,
    this.placedAt = 0,
    this.dispatchedAt = 0,
    this.onWayAt = 0,
    this.deliveredAt = 0,
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

  /// How much the customer has to hand over at the door, in whole VND.
  ///
  /// The itemised [quote] wins over the flat [amount] because the quote is
  /// what the customer was actually shown on the payment screen. Orders
  /// written before the breakdown existed fall back to [amount].
  ///
  /// This is the number the courier has to collect — and therefore the
  /// number the settlement step compares the collected cash against.
  int get codAmountVnd {
    final quoted = quote?.total;
    if (quoted != null && quoted > 0) return quoted;
    return amount.round();
  }

  /// The lifecycle timestamp key a status change has to stamp.
  ///
  /// Returns `null` for a status that does not mark a moment in the
  /// lifecycle (e.g. `CANCELLED` — the order never got that far, and the
  /// time it died is already covered by [placedAt]).
  ///
  /// The mapping is the single source of truth, so every writer — the
  /// admin console, the driver flow and the client — stamps the same key
  /// for the same status.
  static String? timestampKeyFor(String status) {
    switch (status) {
      case statusDispatched:
        return 'dispatchedAt';
      case statusOnWay:
      case 'PICKED UP':
        return 'onWayAt';
      case statusDelivered:
        return 'deliveredAt';
      default:
        return null;
    }
  }

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
        if (quote != null) 'quote': quote!.toMap(),
        if (distanceKm > 0) 'distanceKm': distanceKm,
        'cashCollected': cashCollected,
        if (cashCollectedAt > 0) 'cashCollectedAt': cashCollectedAt,
        if (collectedAmountVnd > 0) 'collectedAmountVnd': collectedAmountVnd,
        if (placedAt > 0) 'placedAt': placedAt,
        if (dispatchedAt > 0) 'dispatchedAt': dispatchedAt,
        if (onWayAt > 0) 'onWayAt': onWayAt,
        if (deliveredAt > 0) 'deliveredAt': deliveredAt,
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

  /// Reads the persisted money breakdown, if the row has one.
  ///
  /// Orders written before the breakdown existed simply have no quote.
  static PriceBreakdown? _readQuote(Map<dynamic, dynamic> map) {
    final raw = map['quote'];
    if (raw is! Map) return null;
    return PriceBreakdown.fromMap(Map<dynamic, dynamic>.from(raw));
  }

  /// Reads a lifecycle timestamp, tolerating a missing or malformed value.
  ///
  /// Rows written before the timestamps existed fall back to `createdAt`
  /// for [placedAt] — the order *was* placed at that moment — and to 0
  /// for the later stages, which never happened.
  static int _readTimestamp(Map<dynamic, dynamic> map, String key) {
    final raw = map[key];
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse(raw?.toString() ?? '');
    if (parsed != null) return parsed;
    if (key == 'placedAt') {
      final created = int.tryParse((map['createdAt'] ?? '0').toString()) ?? 0;
      return created;
    }
    return 0;
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
      quote: _readQuote(map),
      distanceKm: double.tryParse((map['distanceKm'] ?? '0').toString()) ?? 0.0,
      cashCollected: map['cashCollected'] == true,
      cashCollectedAt: int.tryParse((map['cashCollectedAt'] ?? '0').toString()) ?? 0,
      collectedAmountVnd: int.tryParse((map['collectedAmountVnd'] ?? '0').toString()) ?? 0,
      placedAt: _readTimestamp(map, 'placedAt'),
      dispatchedAt: _readTimestamp(map, 'dispatchedAt'),
      onWayAt: _readTimestamp(map, 'onWayAt'),
      deliveredAt: _readTimestamp(map, 'deliveredAt'),
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
    PriceBreakdown? quote,
    double? distanceKm,
    bool? cashCollected,
    int? cashCollectedAt,
    int? collectedAmountVnd,
    int? placedAt,
    int? dispatchedAt,
    int? onWayAt,
    int? deliveredAt,
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
      quote: quote ?? this.quote,
      distanceKm: distanceKm ?? this.distanceKm,
      cashCollected: cashCollected ?? this.cashCollected,
      cashCollectedAt: cashCollectedAt ?? this.cashCollectedAt,
      collectedAmountVnd: collectedAmountVnd ?? this.collectedAmountVnd,
      placedAt: placedAt ?? this.placedAt,
      dispatchedAt: dispatchedAt ?? this.dispatchedAt,
      onWayAt: onWayAt ?? this.onWayAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      deliveryPhoto: deliveryPhoto ?? this.deliveryPhoto,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      receiverName: receiverName ?? this.receiverName,
      rejectedBy: rejectedBy ?? this.rejectedBy,
    );
  }
}
