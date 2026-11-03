/// Delivery address (UC-04 / UC-06).
///
/// Đã lược bỏ latitude và longitude theo yêu cầu nghiệp vụ.
class Address {
  final String id;
  final String street;
  final String reference;

  const Address({
    required this.id,
    required this.street,
    required this.reference,
  });

  factory Address.fromMap(String id, Map<dynamic, dynamic> map) {
    return Address(
      id: id,
      street: (map['street'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'street': street,
    'reference': reference,
  };

  /// Default address used when the user has not yet wired UC-06.
  static const Address hardcodedDefault = Address(
    id: 'default',
    street: '1 Lê Lợi, Bến Nghé',
    reference: 'District 1, Ho Chi Minh City',
  );
}