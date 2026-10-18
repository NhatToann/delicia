import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/image_product.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_cart.dart';
import '../../components/btn_frave.dart';
import '../../components/shimmer_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/modal_success.dart';
import '../../themes/colors_frave.dart';

/// ProductDetailScreen — full-screen view for a single product.
///
/// Loads the product + carousel images via [ProductsBloc], lets the user
/// pick a quantity (1–99) and adds the item to the cart via [CartBloc].
class ProductDetailScreen extends StatefulWidget {
  final String productId;
  const ProductDetailScreen({super.key, required this.productId});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context
          .read<ProductsBloc>()
          .add(OnGetDetailsProductEvent(widget.productId));
    });
  }

  @override
  void dispose() {
    // Clear the current product so navigating back doesn't leak memory.
    context.read<ProductsBloc>().add(const OnClearCurrentProductEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: BlocConsumer<ProductsBloc, ProductsState>(
        listenWhen: (a, b) =>
            (b.error != null && a.error != b.error) ||
            (b.currentProduct != null && a.currentProduct == null),
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          }
        },
        builder: (_, state) {
          final product = state.currentProduct;
          if (state.isLoadingDetails || product == null) {
            return _LoadingShell(productId: widget.productId);
          }
          // Build a list of picture references in priority order:
          // 1) extra carousel images returned by the backend
          // 2) the primary picture stored on the product
          final imageRefs = <String>[
            for (final ImageProductdb img in state.currentImages) img.picture,
            if (product.picture.isNotEmpty) product.picture,
          ];
          return _LoadedShell(
            product: product,
            imageRefs: imageRefs,
            quantity: _quantity,
            onIncrease: _increase,
            onDecrease: _decrease,
            onAddToCart: () => _addToCart(product, imageRefs),
            onBack: () => context.pop(),
          );
        },
      ),
    );
  }

  void _increase() {
    if (_quantity >= 99) return;
    setState(() => _quantity++);
    context.read<CartBloc>().add(const OnIncreaseProductQuantityEvent());
  }

  void _decrease() {
    if (_quantity <= 1) return;
    setState(() => _quantity--);
    context.read<CartBloc>().add(const OnDecreaseProductQuantityEvent());
  }

  void _addToCart(Productsdb product, List<String> imageRefs) {
    // Store the raw picture reference (asset path or URL) so the cart
    // screen can re-resolve it later without keeping a baked-in URL.
    final imageRef = imageRefs.isNotEmpty ? imageRefs.first : product.picture;
    context.read<CartBloc>().add(OnAddProductToCartEvent(
          ProductCart(
            uidProduct: product.id,
            imageProduct: imageRef,
            nameProduct: product.nameProduct,
            price: product.price,
            quantity: _quantity,
          ),
        ));
    modalSuccess(context, 'Added to cart', onDone: () => context.pop());
  }
}

class _LoadingShell extends StatelessWidget {
  final String productId;
  const _LoadingShell({required this.productId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerFrave(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerTile(height: 240),
                    SizedBox(height: 16),
                    ShimmerTile(height: 24, width: 200),
                    SizedBox(height: 8),
                    ShimmerTile(height: 18, width: 100),
                    SizedBox(height: 16),
                    ShimmerTile(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadedShell extends StatelessWidget {
  final Productsdb product;
  final List<String> imageRefs;
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onAddToCart;
  final VoidCallback onBack;

  const _LoadedShell({
    required this.product,
    required this.imageRefs,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
    required this.onAddToCart,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Stack(
            children: [
              SizedBox(
                height: 300,
                width: double.infinity,
                child: _ProductCarousel(
                  imageRefs: imageRefs,
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: onBack,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextCustom(
                    product.nameProduct,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 6),
                  TextCustom(
                    '\$${product.price.toStringAsFixed(2)}',
                    fontSize: 22,
                    color: ColorsFrave.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: TextCustom(
                        product.description,
                        color: ColorsFrave.greyText,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const TextCustom(
                        'Quantity',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: quantity > 1 ? onDecrease : null,
                          ),
                          TextCustom(
                            quantity.toString(),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: quantity < 99 ? onIncrease : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  BtnFrave(
                    text:
                        'Add to Cart  \$${(product.price * quantity).toStringAsFixed(2)}',
                    onPressed: onAddToCart,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lightweight paged-image carousel backed by Flutter's built-in
/// `PageView` (no third-party dependency — avoids the
/// `CarouselController` name-collision between `carousel_slider` and
/// `flutter/material.dart` on Flutter 3.27+).
class _ProductCarousel extends StatefulWidget {
  const _ProductCarousel({required this.imageRefs});

  final List<String> imageRefs;

  @override
  State<_ProductCarousel> createState() => _ProductCarouselState();
}

class _ProductCarouselState extends State<_ProductCarousel> {
  late final PageController _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageRefs.isEmpty) {
      return Container(
        color: ColorsFrave.backgroundColor,
        alignment: Alignment.center,
        child: const Icon(
          Icons.image_outlined,
          size: 80,
          color: ColorsFrave.greyText,
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          itemCount: widget.imageRefs.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => ImageResolver.resolveWidget(
            widget.imageRefs[i],
            fit: BoxFit.cover,
            fallback: 'assets/icons/no-data.svg',
          ),
        ),
        if (widget.imageRefs.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageRefs.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 8,
                  width: active ? 20 : 8,
                  decoration: BoxDecoration(
                    color: active
                        ? ColorsFrave.primaryColor
                        : ColorsFrave.greyText,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}
