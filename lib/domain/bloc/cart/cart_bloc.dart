import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/product_cart.dart';

part 'cart_event.dart';
part 'cart_state.dart';

/// CartBloc — manages the in-memory shopping cart (UC-04).
///
/// State: a list of [ProductCart] entries, the total cart quantity, and
/// the total price (sum of price × quantity). Quantities per item are
/// mutated in-place to keep the API simple — the widgets use the index
/// when adding/removing to keep these mutations scoped.
class CartBloc extends Bloc<CartEvent, CartState> {
  CartBloc() : super(const CartState()) {
    on<OnAddProductToCartEvent>(_onAdd);
    on<OnDeleteProductToCartEvent>(_onDelete);
    on<OnIncreaseQuantityProductToCartEvent>(_onIncrease);
    on<OnDecreaseProductQuantityToCartEvent>(_onDecrease);
    on<OnClearCartEvent>(_onClear);
    on<OnIncreaseProductQuantityEvent>(_onIncreaseSelected);
    on<OnDecreaseProductQuantityEvent>(_onDecreaseSelected);
    on<OnResetQuantityEvent>(_onResetSelected);
  }

  void _onAdd(OnAddProductToCartEvent event, Emitter<CartState> emit) {
    final next = List<ProductCart>.from(state.products ?? const []);
    // The same dish in two different sizes is two separate cart lines, so
    // the lookup keys on the product *and* the selected option.
    final idx = next.indexWhere((p) => p.lineKey == event.productCart.lineKey);
    if (idx == -1) {
      next.add(event.productCart);
    } else {
      // Increment the existing item — add-to-cart from the detail screen
      // should aggregate quantity if the user taps twice.
      next[idx] = next[idx].copyWith(
        quantity: next[idx].quantity + event.productCart.quantity,
      );
    }
    emit(state.copyWith(products: next, selectedQuantity: 1));
  }

  void _onDelete(OnDeleteProductToCartEvent event, Emitter<CartState> emit) {
    final next = List<ProductCart>.from(state.products ?? const []);
    if (event.index < 0 || event.index >= next.length) return;
    next.removeAt(event.index);
    emit(state.copyWith(products: next));
  }

  void _onIncrease(
    OnIncreaseQuantityProductToCartEvent event,
    Emitter<CartState> emit,
  ) {
    final next = List<ProductCart>.from(state.products ?? const []);
    if (event.index < 0 || event.index >= next.length) return;
    final current = next[event.index];
    if (current.quantity >= 99) return; // spec UC-04: cap at 99
    next[event.index] = current.copyWith(quantity: current.quantity + 1);
    emit(state.copyWith(products: next));
  }

  void _onDecrease(
    OnDecreaseProductQuantityToCartEvent event,
    Emitter<CartState> emit,
  ) {
    final next = List<ProductCart>.from(state.products ?? const []);
    if (event.index < 0 || event.index >= next.length) return;
    final current = next[event.index];
    if (current.quantity <= 0) return;
    if (current.quantity == 1) {
      // The last remaining unit is taken out of the cart: a line with a
      // quantity of 0 is removed instead of being kept around.
      next.removeAt(event.index);
    } else {
      next[event.index] = current.copyWith(quantity: current.quantity - 1);
    }
    emit(state.copyWith(products: next));
  }

  void _onClear(OnClearCartEvent event, Emitter<CartState> emit) {
    emit(const CartState());
  }

  // ---------------------------------------------------------------------------
  // The next 3 events mirror the *currently selected* product quantity on the
  // product detail screen. They are intentionally decoupled from the cart list
  // so the UI can show "Quantity: 1" before any add-to-cart happens.
  // ---------------------------------------------------------------------------

  void _onIncreaseSelected(
    OnIncreaseProductQuantityEvent event,
    Emitter<CartState> emit,
  ) {
    emit(state.copyWith(selectedQuantity: state.selectedQuantity + 1));
  }

  void _onDecreaseSelected(
    OnDecreaseProductQuantityEvent event,
    Emitter<CartState> emit,
  ) {
    final next = state.selectedQuantity - 1;
    if (next < 1) return;
    emit(state.copyWith(selectedQuantity: next));
  }

  void _onResetSelected(
    OnResetQuantityEvent event,
    Emitter<CartState> emit,
  ) {
    emit(state.copyWith(selectedQuantity: 1));
  }
}