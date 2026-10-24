/// Delivery address (UC-04 / UC-06).
///
/// Stub model — the full address CRUD is owned by Member A in UC-06, but
/// the checkout flow needs at least one hardcoded address to compile end
/// to end. The Leader-managed checkout uses the first address returned
/// here as the default selection.
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
    required this.latitude,
    required this.longitude,
  });

  factory Address.fromMap(String id, Map<dynamic, dynamic> map) {
    return Address(
      id: id,
      street: (map['street'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      latitude:
          double.tryParse((map['latitude'] ?? '0').toString()) ?? 0.0,
      longitude:
          double.tryParse((map['longitude'] ?? '0').toString()) ?? 0.0,
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
    latitude: 10.7717,
    longitude: 106.7009,
  );
}