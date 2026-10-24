/// Single product entry held inside [CartState] (UC-04).
///
/// Mirrors the original `ProductCart` model from the reference Frave app.
class ProductCart {
  final String uidProduct;
  final String imageProduct;
  final String nameProduct;
  final double price;
  final int quantity;

  const ProductCart({
    required this.uidProduct,
    required this.imageProduct,
    required this.nameProduct,
    required this.price,
    required this.quantity,
  });

  ProductCart copyWith({
    String? uidProduct,
    String? imageProduct,
    String? nameProduct,
    double? price,
    int? quantity,
  }) =>
      ProductCart(
        uidProduct: uidProduct ?? this.uidProduct,
        imageProduct: imageProduct ?? this.imageProduct,
        nameProduct: nameProduct ?? this.nameProduct,
        price: price ?? this.price,
        quantity: quantity ?? this.quantity,
      );

  Map<String, dynamic> toJson() => {
        'uidProduct': uidProduct,
        'imageProduct': imageProduct,
        'nameProduct': nameProduct,
        'price': price,
        'quantity': quantity,
      };

  factory ProductCart.fromJson(Map<dynamic, dynamic> json) => ProductCart(
        uidProduct: (json['uidProduct'] ?? '').toString(),
        imageProduct: (json['imageProduct'] ?? '').toString(),
        nameProduct: (json['nameProduct'] ?? '').toString(),
        price: double.tryParse((json['price'] ?? 0).toString()) ?? 0.0,
        quantity: int.tryParse((json['quantity'] ?? 1).toString()) ?? 1,
      );
}