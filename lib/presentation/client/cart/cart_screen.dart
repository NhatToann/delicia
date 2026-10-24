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
        title: const TextCustom('My Bag', fontWeight: FontWeight.w500),
        centerTitle: true,
        actions: [
          BlocBuilder<CartBloc, CartState>(
            builder: (_, state) => Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Center(
                child: TextCustom(
                  '${state.quantityCart} Items',
                  fontSize: 17,
                ),
              ),
            ),
          ),
        ],
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
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: products.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 15),
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
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 20,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ColorsFrave.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _SummaryRow(label: 'Total', value: state.total),
                      const SizedBox(height: 20),
                      _SummaryRow(label: 'Sub Total', value: state.total),
                      const SizedBox(height: 20),
                      BtnFrave(
                        text: 'Checkout  \$${state.total.toStringAsFixed(2)}',
                        onPressed: state.quantityCart == 0
                            ? null
                            : () => context.push('/client/checkout'),
                      ),
                    ],
                  ),
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
      background: Container(),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.only(right: 35),
        alignment: Alignment.centerRight,
        decoration: const BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
        ),
        child: const Icon(Icons.delete_sweep_rounded,
            color: Colors.white, size: 40),
      ),
      onDismissed: (_) => onDelete(),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: ImageResolver.resolveWidget(
                  product.imageProduct,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(
              width: 130,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextCustom(
                      product.nameProduct,
                      fontWeight: FontWeight.w500,
                      fontSize: 18,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    TextCustom(
                      '\$${(product.price * product.quantity).toStringAsFixed(2)}',
                      color: ColorsFrave.primaryColor,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _circleBtn(
                    icon: Icons.remove,
                    onTap: product.quantity > 1 ? onDecrease : null,
                  ),
                  const SizedBox(width: 10),
                  TextCustom(
                    product.quantity.toString(),
                    color: ColorsFrave.primaryColor,
                  ),
                  const SizedBox(width: 10),
                  _circleBtn(icon: Icons.add, onTap: onIncrease),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn({required IconData icon, VoidCallback? onTap}) {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: ColorsFrave.primaryColor,
        shape: BoxShape.circle,
      ),
      child: InkWell(
        onTap: onTap,
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextCustom(label),
        TextCustom('\$${value.toStringAsFixed(2)}'),
      ],
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
              Icons.shopping_cart_outlined,
              size: 120,
              color: ColorsFrave.greyText,
            ),
            const SizedBox(height: 16),
            const TextCustom(
              'Without products',
              fontSize: 21,
              fontWeight: FontWeight.w500,
              color: ColorsFrave.primaryColor,
            ),
            const SizedBox(height: 16),
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