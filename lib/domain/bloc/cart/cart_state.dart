part of 'cart_bloc.dart';

@immutable
class CartState {
  final List<ProductCart>? products;
  final int selectedQuantity;

  const CartState({
    this.products,
    this.selectedQuantity = 1,
  });

  /// Total quantity across all products in the cart (used for the badge).
  int get quantityCart =>
      (products ?? const []).fold(0, (sum, p) => sum + p.quantity);

  /// Sum of price × quantity across all products.
  double get total => (products ?? const [])
      .fold(0, (sum, p) => sum + p.price * p.quantity);

  CartState copyWith({
    List<ProductCart>? products,
    int? selectedQuantity,
  }) {
    return CartState(
      products: products ?? this.products,
      selectedQuantity: selectedQuantity ?? this.selectedQuantity,
    );
  }
}