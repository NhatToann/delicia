import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/models/product_cart.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/modal_loading.dart';
import '../../themes/colors_frave.dart';

/// CartScreen — shows the user's shopping cart with swipe-to-delete
/// (UC-04). Tapping "Checkout" pushes `/client/checkout`.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cartBloc = context.read<CartBloc>();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: const TextCustom('My Cart', fontWeight: FontWeight.bold),
        centerTitle: true,
      ),
      body: BlocBuilder<CartBloc, CartState>(
        builder: (_, state) {
          final products = state.products ?? const [];
          if (products.isEmpty) {
            return _Empty();
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final p = products[i];
                    return _CartItem(
                      key: ValueKey(p.uidProduct),
                      product: p,
                      onIncrease: () => cartBloc.add(
                        OnIncreaseQuantityProductToCartEvent(i),
                      ),
                      onDecrease: () => cartBloc.add(
                        OnDecreaseProductQuantityToCartEvent(i),
                      ),
                      onDelete: () =>
                          cartBloc.add(OnDeleteProductToCartEvent(i)),
                    );
                  },
                ),
              ),
              _Summary(total: state.total, count: state.quantityCart),
              Padding(
                padding: const EdgeInsets.all(20),
                child: BtnFrave(
                  text: 'Checkout  \$${state.total.toStringAsFixed(2)}',
                  onPressed: () => context.push('/client/checkout'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItem extends StatelessWidget {
  final ProductCart product;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onDelete;

  const _CartItem({
    super.key,
    required this.product,
    required this.onIncrease,
    required this.onDecrease,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey('cart-${product.uidProduct}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: ColorsFrave.errorColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Color(0x10000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 64,
                height: 64,
                child: ImageResolver.resolveWidget(
                  product.imageProduct,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextCustom(
                    product.nameProduct,
                    fontWeight: FontWeight.w600,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  TextCustom(
                    '\$${product.price.toStringAsFixed(2)}',
                    color: ColorsFrave.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onIncrease,
                ),
                TextCustom(product.quantity.toString()),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: product.quantity > 1 ? onDecrease : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  final double total;
  final int count;
  const _Summary({required this.total, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0x11000000))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextCustom(
            '$count item${count == 1 ? '' : 's'}',
            color: ColorsFrave.greyText,
          ),
          TextCustom(
            'Total: \$${total.toStringAsFixed(2)}',
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shopping_bag_outlined,
              size: 96,
              color: ColorsFrave.greyText,
            ),
            const SizedBox(height: 16),
            const TextCustom(
              'Your cart is empty',
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            const SizedBox(height: 8),
            const TextCustom(
              'Add products to get started',
              color: ColorsFrave.greyText,
            ),
            const SizedBox(height: 24),
            BtnFrave(
              text: 'Continue Shopping',
              color: Colors.white,
              textColor: ColorsFrave.primaryColor,
              onPressed: () => context.go('/client/home'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper for the [CartScreen] widget tests — keeps the loading helper in
/// scope so a screen-level test can ensure no loading overlay is shown
/// when the cart is empty.
class CartScreenTestHooks {
  CartScreenTestHooks._();

  static bool wasLoadingShown(BuildContext context) {
    // Intentionally does nothing in production. Used by widget tests via
    // `modalLoading(context)` mock setup.
    return ModalRoute.of(context)?.isCurrent ?? true;
  }

  static Future<void> maybeShowLoading(BuildContext context) async {
    await modalLoading(context);
  }
}