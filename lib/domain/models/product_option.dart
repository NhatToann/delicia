/// A selectable size / portion of a product (UC-02).
///
/// Figma node `192:1216` ("7 - A - Advertising Banner" — the product-detail
/// frame) draws a *Personal portion* list where every row pairs a size
/// label with its own price and a radio button:
///
///     Personal (4 Slides)    $0.00
///     Medium (8 Slides)      $3.00
///     Familiar (10 Slides)   $6.00
///     Jumbo (12 Slides)      $10.00
///
/// The prices in that frame are layout samples, so the real numbers live in
/// the database: every product carries an `options` array under
/// `/delicia/products/{id}/options`, and each entry carries its own
/// absolute `price`. Nothing here is hardcoded in the widget layer.
///
/// The option id is stable (`opt1`, `opt2`, …) so the cart and the order
/// snapshot can point back at the exact variant the customer picked.
class ProductOption {
  /// Stable identifier, e.g. `opt2`.
  final String id;

  /// Human-readable size label, e.g. `Vừa (8 phần)`.
  final String label;

  /// Price of this variant in USD (the catalogue's base currency).
  ///
  /// This is the *absolute* price of the variant, not a delta — the
  /// database owns the number so the screen never has to compute it.
  final double price;

  const ProductOption({
    required this.id,
    required this.label,
    required this.price,
  });

  factory ProductOption.fromMap(String id, Map<dynamic, dynamic> map) {
    return ProductOption(
      id: (map['id'] ?? id).toString(),
      label: (map['label'] ?? '').toString(),
      price: _parseDouble(map['price']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'price': price,
      };

  static double _parseDouble(dynamic raw) {
    if (raw == null) return 0.0;
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw.toString()) ?? 0.0;
  }

  @override
  bool operator ==(Object other) =>
      other is ProductOption &&
      other.id == id &&
      other.label == label &&
      other.price == price;

  @override
  int get hashCode => Object.hash(id, label, price);
}
