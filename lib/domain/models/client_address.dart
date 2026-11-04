/// Delivery address owned by UC-06 (profile / address management).
///
/// This is deliberately a **separate model** from
/// `lib/domain/models/address.dart` (UC-04, Leader).  The Leader's model
/// is a stub used by the checkout flow; it has no `isDefault` flag and
/// changing it would ripple into the checkout / cart screens that other
/// team members own.  Keeping our own model means UC-06 can evolve
/// without touching anyone's files.
class ClientAddress {
  final String id;
  final String street;
  final String reference;
  final double latitude;
  final double longitude;

  /// Marks the user's preferred delivery address.  UC-06 guarantees
  /// exactly one `isDefault = true` per user.
  final bool? isDefault;

  const ClientAddress({
    required this.id,
    required this.street,
    required this.reference,
    required this.latitude,
    required this.longitude,
    this.isDefault,
  });

  /// Parses a Realtime Database snapshot.  Tolerant of malformed values so
  /// a single corrupt row can't break the whole address list.
  factory ClientAddress.fromMap(String id, Map<dynamic, dynamic> map) {
    return ClientAddress(
      id: id,
      street: (map['street'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      latitude: double.tryParse((map['latitude'] ?? '0').toString()) ?? 0.0,
      longitude: double.tryParse((map['longitude'] ?? '0').toString()) ?? 0.0,
      isDefault: _parseBool(map['isDefault']),
    );
  }

  /// Firebase sometimes stores booleans as strings (`"true"`), so accept
  /// both representations.
  static bool? _parseBool(dynamic raw) {
    if (raw is bool) return raw;
    if (raw is String) {
      if (raw.toLowerCase() == 'true') return true;
      if (raw.toLowerCase() == 'false') return false;
    }
    return null;
  }

  Map<String, dynamic> toMap() => {
    'street': street,
    'reference': reference,
    'latitude': latitude,
    'longitude': longitude,
    if (isDefault != null) 'isDefault': isDefault,
  };

  ClientAddress copyWith({
    String? id,
    String? street,
    String? reference,
    double? latitude,
    double? longitude,
    bool? isDefault,
  }) {
    return ClientAddress(
      id: id ?? this.id,
      street: street ?? this.street,
      reference: reference ?? this.reference,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  @override
  String toString() =>
      'ClientAddress(id: $id, street: $street, isDefault: $isDefault)';
}
