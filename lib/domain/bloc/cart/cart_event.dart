part of 'cart_bloc.dart';

@immutable
abstract class CartEvent {
  const CartEvent();
}

class OnAddProductToCartEvent extends CartEvent {
  final ProductCart productCart;
  const OnAddProductToCartEvent(this.productCart);
}

class OnDeleteProductToCartEvent extends CartEvent {
  final int index;
  const OnDeleteProductToCartEvent(this.index);
}

class OnIncreaseQuantityProductToCartEvent extends CartEvent {
  final int index;
  const OnIncreaseQuantityProductToCartEvent(this.index);
}

class OnDecreaseProductQuantityToCartEvent extends CartEvent {
  final int index;
  const OnDecreaseProductQuantityToCartEvent(this.index);
}

class OnClearCartEvent extends CartEvent {
  const OnClearCartEvent();
}

/// Increases the "currently selected" quantity (product detail screen).
class OnIncreaseProductQuantityEvent extends CartEvent {
  const OnIncreaseProductQuantityEvent();
}

class OnDecreaseProductQuantityEvent extends CartEvent {
  const OnDecreaseProductQuantityEvent();
}

class OnResetQuantityEvent extends CartEvent {
  const OnResetQuantityEvent();
}