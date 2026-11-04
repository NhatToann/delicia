/// Delivery address (UC-04 / UC-06).
///
/// `latitude` / `longitude` are optional and default to `0.0`.
///
/// UC-06 (profile / address management) intentionally stopped *storing*
/// the coordinates on the address row — the display name is what the
/// customer sees. The checkout flow, on the other hand, needs them to
/// compute the road distance that drives the delivery fee. Both are
/// satisfied by keeping the fields optional: a row without coordinates
/// simply falls back to `0.0`.
class Address {
  final String id;
  final String street;
  final String reference;
  final double latitude;
  final double longitude;

  const Address({
    required this.id,
    required this.street,
    required this.reference,
    this.latitude = 0.0,
    this.longitude = 0.0,
  });

  factory Address.fromMap(String id, Map<dynamic, dynamic> map) {
    return Address(
      id: id,
      street: (map['street'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      latitude: double.tryParse((map['latitude'] ?? '0').toString()) ?? 0.0,
      longitude: double.tryParse((map['longitude'] ?? '0').toString()) ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() => {
    'street': street,
    'reference': reference,
    'latitude': latitude,
    'longitude': longitude,
  };

  /// Default address used when the user has not yet wired UC-06.
  static const Address hardcodedDefault = Address(
    id: 'default',
    street: '1 Lê Lợi, Bến Nghé',
    reference: 'District 1, Ho Chi Minh City',
  );
}
