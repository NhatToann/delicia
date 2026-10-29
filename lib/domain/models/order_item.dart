import 'product.dart';

/// Single line item in an order payload (UC-04).
///
/// Stored as the `products` array inside an order document. We keep the
/// relevant fields instead of just the product id so historical orders
/// remain readable even after a product is deleted/renamed.
class OrderItem {
  final String productId;
  final String nameProduct;
  final String picture;
  final double price;
  final int quantity;

  /// The size / portion the customer picked on the product-detail screen.
  ///
  /// Snapshotted as plain text so the order history still shows what was
  /// ordered even if the catalogue changes later. Null for orders placed
  /// before sizes existed.
  final String? optionLabel;

  const OrderItem({
    required this.productId,
    required this.nameProduct,
    required this.picture,
    required this.price,
    required this.quantity,
    this.optionLabel,
  });

  double get total => price * quantity;

  factory OrderItem.fromProduct(Productsdb p, int quantity) => OrderItem(
        productId: p.id,
        nameProduct: p.nameProduct,
        picture: p.picture,
        price: p.price,
        quantity: quantity,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'nameProduct': nameProduct,
        'picture': picture,
        'price': price,
        'quantity': quantity,
        if (optionLabel != null) 'optionLabel': optionLabel,
      };

  factory OrderItem.fromMap(Map<dynamic, dynamic> map) => OrderItem(
        productId: (map['productId'] ?? '').toString(),
        nameProduct: (map['nameProduct'] ?? '').toString(),
        picture: (map['picture'] ?? '').toString(),
        price: double.tryParse((map['price'] ?? 0).toString()) ?? 0.0,
        quantity: int.tryParse((map['quantity'] ?? 1).toString()) ?? 1,
        optionLabel: map['optionLabel']?.toString(),
      );
}
