/// Delivery address (UC-04 / UC-06).
///
/// `latitude` / `longitude` are optional and default to `0.0`.
///
/// The checkout flow needs the coordinates to compute the road distance
/// that drives the delivery fee, and the courier navigates to the point,
/// so an address stored without them silently produces a zero fee and a
/// broken route. Every address the app writes therefore carries a real
/// point — the profile form resolves it from the bundled ward dataset,
/// and the map picker returns it directly.
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

  /// Whether this address carries a usable map point.
  ///
  /// `0.0, 0.0` is in the Atlantic — it is never a real delivery point.
  bool get hasCoordinates =>
      latitude != 0.0 && longitude != 0.0 &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

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

  /// Default address used when the user has not yet added one.
  ///
  /// It deliberately carries **no** coordinates: the fallback is the flat
  /// [Environment.defaultDeliveryFee]. Giving it the restaurant's own
  /// coordinates would produce a zero road distance and therefore a zero
  /// delivery fee — see [hasCoordinates] and the address form, which
  /// resolves a real point from the ward the customer picked.
  static const Address hardcodedDefault = Address(
    id: 'default',
    street: '1 Lê Lợi, Bến Nghé',
    reference: 'District 1, Ho Chi Minh City',
  );
}
