/// Single product entry held inside [CartState] (UC-04).
///
/// Mirrors the original `ProductCart` model from the reference Frave app.
class ProductCart {
  final String uidProduct;
  final String imageProduct;
  final String nameProduct;
  final double price;
  final int quantity;

  /// When the line was added to the cart.
  ///
  /// Figma draws a date + time next to every cart row (nodes `202:1664` /
  /// `202:2737` on the cart panel, `199:1739` on the checkout page), so the
  /// timestamp is part of the model rather than something the widgets
  /// invent. It is optional because a restored or manually built cart may
  /// not carry one.
  final DateTime? addedAt;

  /// The size / portion the customer picked on the product-detail screen.
  ///
  /// Two sizes of the same dish are two different cart lines, so the
  /// selected option's id is part of the line's identity. When it is null
  /// the line is the base product with no size selection.
  final String? optionId;

  /// Human-readable label of the selected size, e.g. `Vừa (8 phần)`.
  ///
  /// Stored as text so the cart can render it without a second lookup, and
  /// so it survives in the order snapshot even if the catalogue changes.
  final String? optionLabel;

  const ProductCart({
    required this.uidProduct,
    required this.imageProduct,
    required this.nameProduct,
    required this.price,
    required this.quantity,
    this.addedAt,
    this.optionId,
    this.optionLabel,
  });

  /// Identity of a cart line.
  ///
  /// The same dish in two different sizes is two separate lines, so the
  /// selected option participates in the identity check.
  String get lineKey =>
      optionId == null ? uidProduct : '$uidProduct#$optionId';

  ProductCart copyWith({
    String? uidProduct,
    String? imageProduct,
    String? nameProduct,
    double? price,
    int? quantity,
    DateTime? addedAt,
    String? optionId,
    String? optionLabel,
  }) =>
      ProductCart(
        uidProduct: uidProduct ?? this.uidProduct,
        imageProduct: imageProduct ?? this.imageProduct,
        nameProduct: nameProduct ?? this.nameProduct,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
        addedAt: addedAt ?? this.addedAt,
        optionId: optionId ?? this.optionId,
        optionLabel: optionLabel ?? this.optionLabel,
      );

  Map<String, dynamic> toJson() => {
        'uidProduct': uidProduct,
        'imageProduct': imageProduct,
        'nameProduct': nameProduct,
        'price': price,
        'quantity': quantity,
        'addedAt': addedAt?.millisecondsSinceEpoch,
        if (optionId != null) 'optionId': optionId,
        if (optionLabel != null) 'optionLabel': optionLabel,
      };

  factory ProductCart.fromJson(Map<dynamic, dynamic> json) => ProductCart(
        uidProduct: (json['uidProduct'] ?? '').toString(),
        imageProduct: (json['imageProduct'] ?? '').toString(),
        nameProduct: (json['nameProduct'] ?? '').toString(),
        price: double.tryParse((json['price'] ?? 0).toString()) ?? 0.0,
        quantity: int.tryParse((json['quantity'] ?? 1).toString()) ?? 1,
        addedAt: _readTimestamp(json['addedAt']),
        optionId: json['optionId']?.toString(),
        optionLabel: json['optionLabel']?.toString(),
      );

  /// Reads a timestamp that may be stored as epoch millis, as an ISO
  /// string, or not at all.
  static DateTime? _readTimestamp(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    final millis = int.tryParse(text);
    if (millis != null) return DateTime.fromMillisecondsSinceEpoch(millis);
    return DateTime.tryParse(text);
  }
}
