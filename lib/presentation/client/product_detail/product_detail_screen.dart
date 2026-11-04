import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/cart/cart_bloc.dart';
import '../../../domain/bloc/products/products_bloc.dart';
import '../../../domain/models/image_product.dart';
import '../../../domain/models/product.dart';
import '../../../domain/models/product_cart.dart';
import '../../../domain/models/product_option.dart';
import '../../components/app_bottom_nav.dart';
import '../../components/app_nav_destination.dart';
import '../../components/shimmer_frave.dart';
import '../../helpers/error_message.dart';
import '../../helpers/image_resolver.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/money.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';
import '../cart/cart_screen.dart';
import 'widgets/discount_badge.dart';
import 'widgets/product_detail_geometry.dart';
import 'widgets/product_size_row.dart';

/// ProductDetailScreen — full-screen view for a single product.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  String? _selectedOptionId;
  ProductsBloc? _productsBloc;
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<CartBloc>().add(const OnResetQuantityEvent());
      _productsBloc = context.read<ProductsBloc>();
      _productsBloc!.add(OnGetDetailsProductEvent(widget.productId));
    });
  }

  @override
  void dispose() {
    _productsBloc?.add(const OnClearCurrentProductEvent());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.headerYellow,
      bottomNavigationBar: AppBottomNav(
        currentIndex: AppNavDestination.home,
        onTap: (index) => AppNavDestination.go(context, index),
        onTapCart: _openCart,
      ),
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
            return const _LoadingShell();
          }
          final imageRefs = <String>[
            for (final ImageProductdb img in state.currentImages) img.picture,
            if (product.picture.isNotEmpty) product.picture,
          ];
          return BlocBuilder<CartBloc, CartState>(
            buildWhen: (a, b) => a.selectedQuantity != b.selectedQuantity,
            builder: (context, cartState) {
              final quantity = cartState.selectedQuantity;
              return _LoadedShell(
                product: product,
                imageRefs: imageRefs,
                quantity: quantity,
                selectedOptionId: _selectedOptionId,
                onIncrease: _increase,
                onDecrease: _decrease,
                onSelectOption: _selectOption,
                onAddToCart: () => _addToCart(product, imageRefs, quantity),
                onBack: _goBack,
              );
            },
          );
        },
      ),
    );
  }

  void _goBack() {
    if (!mounted) return;
    goBack(context);
  }

  void _openCart() {
    CartOverlay.show(
      context,
      onCheckout: () => context.push('/client/payment'),
    );
  }

  void _increase() {
    final bloc = context.read<CartBloc>();
    if (bloc.state.selectedQuantity >= 99) return;
    bloc.add(const OnIncreaseProductQuantityEvent());
  }

  void _decrease() {
    final bloc = context.read<CartBloc>();
    if (bloc.state.selectedQuantity <= 1) return;
    bloc.add(const OnDecreaseProductQuantityEvent());
  }

  void _selectOption(String optionId) {
    setState(() => _selectedOptionId = optionId);
  }

  void _addToCart(Productsdb product, List<String> imageRefs, int quantity) {
    if (_addingToCart) return;

    final imageRef = imageRefs.isNotEmpty ? imageRefs.first : product.picture;
    final option = _selectedOption(product);

    context.read<CartBloc>().add(
      OnAddProductToCartEvent(
        ProductCart(
          uidProduct: product.id,
          imageProduct: imageRef,
          nameProduct: product.nameProduct,
          price: option?.price ?? product.price,
          quantity: quantity,
          addedAt: DateTime.now(),
          optionId: option?.id,
          optionLabel: option?.label,
        ),
      ),
    );

    _showAddedToCartConfirmation();
  }

  void _showAddedToCartConfirmation() {
    setState(() => _addingToCart = true);

    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: <Widget>[
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.productAddedToCart,
                  style: FraveText.medium(13, color: Colors.white),
                ),
              ),
            ],
          ),
          backgroundColor: ColorsFrave.navOrange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(milliseconds: 1400),
        ),
      ).closed.then((_) {
        if (!mounted) return;
        setState(() => _addingToCart = false);
      });
  }

  ProductOption? _selectedOption(Productsdb product) {
    final options = product.options;
    if (options.isEmpty) return null;
    final id = _selectedOptionId;
    if (id != null) {
      for (final option in options) {
        if (option.id == id) return option;
      }
    }
    return options.first;
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    final systemTop = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(
        top: systemTop + ProductDetailGeometry.headerTop,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: ProductDetailGeometry.pageInset,
            ),
            child: _LoadingBar(width: 160, height: 18),
          ),
          const SizedBox(height: 24),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: ShimmerTile(height: 220),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _LoadedShell extends StatelessWidget {
  const _LoadedShell({
    required this.product,
    required this.imageRefs,
    required this.quantity,
    required this.selectedOptionId,
    required this.onIncrease,
    required this.onDecrease,
    required this.onSelectOption,
    required this.onAddToCart,
    required this.onBack,
  });

  final Productsdb product;
  final List<String> imageRefs;
  final int quantity;
  final String? selectedOptionId;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final ValueChanged<String> onSelectOption;
  final VoidCallback onAddToCart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final options = product.options;
    final selected = _selectedOption(options);
    final unitPrice = selected?.price ?? product.price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _HeaderBand(
          title: product.nameProduct,
          productId: product.id,
          onBack: onBack,
        ),
        Expanded(
          child: Container(
            decoration: const BoxDecoration(
              color: ColorsFrave.pageBg,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      ProductDetailGeometry.pageInset,
                      ProductDetailGeometry.photoTopInset,
                      ProductDetailGeometry.pageInset,
                      0,
                    ),
                    child: _ProductPhoto(
                      imageRefs: imageRefs,
                      fallback: product.picture,
                      discountPercent: product.discountPercent,
                    ),
                  ),
                  const SizedBox(height: ProductDetailGeometry.priceGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ProductDetailGeometry.pageInset,
                    ),
                    child: _PriceRow(
                      price: unitPrice,
                      oldPrice: product.oldPrice,
                      quantity: quantity,
                      onIncrease: onIncrease,
                      onDecrease: onDecrease,
                    ),
                  ),
                  const SizedBox(height: ProductDetailGeometry.titleGap),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ProductDetailGeometry.pageInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                product.nameProduct,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: FraveText.bold(
                                  20,
                                  color: ColorsFrave.ink,
                                  height: 1.15,
                                ),
                              ),
                            ),
                            if (product.hasRating) ...<Widget>[
                              const SizedBox(width: 10),
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: _RatingBadge(rating: product.rating),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(
                          height: ProductDetailGeometry.descriptionGap,
                        ),
                        Text(
                          product.description,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: FraveText.regular(
                            13,
                            color: ColorsFrave.greyText,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: ProductDetailGeometry.sizeGap),
                  if (options.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ProductDetailGeometry.pageInset,
                      ),
                      child: Text(
                        context.l10n.productDetailNoOptions,
                        style: FraveText.regular(
                          13,
                          color: ColorsFrave.lightGrey,
                        ),
                      ),
                    )
                  else ...<Widget>[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ProductDetailGeometry.pageInset,
                      ),
                      child: Text(
                        context.l10n.productSizeTitle,
                        style: FraveText.bold(15, color: ColorsFrave.ink),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: ProductDetailGeometry.pageInset,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          for (final option in options)
                            ProductSizeRow(
                              option: option,
                              selected:
                              option.id ==
                                  (selected?.id ?? selectedOptionId),
                              onTap: () => onSelectOption(option.id),
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: ProductDetailGeometry.ctaGap),
                  LayoutBuilder(
                    builder: (context, constraints) => Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: ProductDetailGeometry.ctaInsetFor(
                          constraints.maxWidth,
                        ),
                      ),
                      child: _AddToCartButton(
                        price: unitPrice * quantity,
                        onTap: onAddToCart,
                      ),
                    ),
                  ),
                  const SizedBox(height: ProductDetailGeometry.ctaBottomGap),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  ProductOption? _selectedOption(List<ProductOption> options) {
    if (options.isEmpty) return null;
    final id = selectedOptionId;
    if (id != null) {
      for (final option in options) {
        if (option.id == id) return option;
      }
    }
    return options.first;
  }
}

class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.title,
    required this.productId,
    required this.onBack,
  });

  final String title;
  final String productId;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final systemTop = MediaQuery.paddingOf(context).top;

    return Padding(
      padding: EdgeInsets.only(
        top: systemTop + ProductDetailGeometry.headerTop,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          ProductDetailGeometry.backButtonLeft,
          0,
          ProductDetailGeometry.pageInset,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                _BackButton(onTap: onBack),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FraveText.medium(
                      17,
                      color: ColorsFrave.ink,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _FavouriteButton(productId: productId),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.actionBack,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: ProductDetailGeometry.backButtonHitSize,
            height: ProductDetailGeometry.backButtonHitSize,
            child: Center(
              child: SvgPicture.asset(
                'assets/figma_payment/back_arrow.svg',
                width: ProductDetailGeometry.backButtonWidth,
                height: ProductDetailGeometry.backButtonHeight,
                fit: BoxFit.contain,
                colorFilter: const ColorFilter.mode(
                  ColorsFrave.ink,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      buildWhen: (a, b) =>
      a.favorites.contains(productId) != b.favorites.contains(productId),
      builder: (context, state) {
        final isFavourite = state.favorites.contains(productId);
        return Semantics(
          button: true,
          label: isFavourite
              ? context.l10n.productDetailUnfavorite
              : context.l10n.productDetailFavorite,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _toggle(context, isFavourite),
              child: SizedBox(
                width: ProductDetailGeometry.heartHitSize,
                height: ProductDetailGeometry.heartHitSize,
                child: Center(
                  child: SvgPicture.asset(
                    isFavourite
                        ? 'assets/figma_home/favorite_on.svg'
                        : 'assets/figma_home/favorite_off.svg',
                    width: ProductDetailGeometry.heartSize,
                    height: ProductDetailGeometry.heartSize,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggle(BuildContext context, bool wasFavourite) {
    context.read<ProductsBloc>().add(OnToggleFavoriteEvent(productId));

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            wasFavourite
                ? context.l10n.productDetailRemovedFromFavorites
                : context.l10n.productDetailAddedToFavorites,
            style: FraveText.medium(13, color: ColorsFrave.onOrange),
          ),
          backgroundColor: ColorsFrave.navOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      );
  }
}

class _RatingBadge extends StatelessWidget {
  const _RatingBadge({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.productDetailRating(rating.toStringAsFixed(1)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: ColorsFrave.pillYellow,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.asset(
              'assets/figma_home/star.svg',
              width: 11,
              height: 11,
            ),
            const SizedBox(width: 3),
            Text(
              rating.toStringAsFixed(1),
              style: FraveText.medium(12, color: ColorsFrave.ink, height: 1.1),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductPhoto extends StatefulWidget {
  const _ProductPhoto({
    required this.imageRefs,
    required this.fallback,
    this.discountPercent,
  });

  final List<String> imageRefs;
  final String fallback;
  final int? discountPercent;

  @override
  State<_ProductPhoto> createState() => _ProductPhotoState();
}

class _ProductPhotoState extends State<_ProductPhoto> {
  late final PageController _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final refs = widget.imageRefs.isEmpty
        ? <String>[widget.fallback]
        : widget.imageRefs;

    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(ProductDetailGeometry.photoRadius),
      child: AspectRatio(
        aspectRatio: ProductDetailGeometry.photoAspect,
        child: refs.length > 1
            ? PageView.builder(
          controller: _controller,
          itemCount: refs.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (_, i) => ImageResolver.resolveWidget(
            refs[i],
            fit: BoxFit.cover,
            fallback: 'assets/icons/no-data.svg',
          ),
        )
            : ImageResolver.resolveWidget(
          refs.first,
          fit: BoxFit.cover,
          fallback: 'assets/icons/no-data.svg',
        ),
      ),
    );

    return Stack(
      children: <Widget>[
        photo,
        if (widget.discountPercent != null && widget.discountPercent! > 0)
          Positioned(
            top: 0,
            right: 0,
            child: DiscountBadge(percent: widget.discountPercent!),
          ),
        if (refs.length > 1)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(refs.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: active ? 8 : 6,
                  width: active ? 20 : 6,
                  decoration: BoxDecoration(
                    color: active
                        ? ColorsFrave.navOrange
                        : ColorsFrave.onOrange.withValues(alpha: 0.6),
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

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.price,
    required this.oldPrice,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  final double price;
  final double? oldPrice;
  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    final hasPrice = price > 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: <Widget>[
              if (hasPrice)
                Text(
                  Money.format(price),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.bold(
                    24,
                    color: ColorsFrave.navOrange,
                    height: 1,
                  ),
                )
              else
                Text(
                  context.l10n.productDetailPriceUnavailable,
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.bold(
                    18,
                    color: ColorsFrave.lightGrey,
                    height: 1,
                  ),
                ),
              if (hasPrice && oldPrice != null && oldPrice! > price)
                Text(
                  Money.format(oldPrice!),
                  maxLines: 1,
                  style: FraveText.regular(
                    13,
                    color: ColorsFrave.lightGrey,
                    height: 1,
                  ).copyWith(decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Stepper(
          quantity: quantity,
          onIncrease: onIncrease,
          onDecrease: onDecrease,
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  final int quantity;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepperButton(
          icon: Icons.remove,
          onTap: quantity > 1 ? onDecrease : null,
          semanticLabel: context.l10n.productQuantity,
        ),
        SizedBox(
          width: 34,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: FraveText.bold(16, color: ColorsFrave.ink, height: 1),
          ),
        ),
        _StepperButton(
          icon: Icons.add,
          onTap: onIncrease,
          semanticLabel: context.l10n.productQuantity,
        ),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: ColorsFrave.navOrange,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: ProductDetailGeometry.stepperSize,
            height: ProductDetailGeometry.stepperSize,
            child: Icon(icon, size: 14, color: ColorsFrave.onOrange),
          ),
        ),
      ),
    );
  }
}

class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.price, required this.onTap});

  final double price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProductDetailGeometry.ctaHeight,
      child: Material(
        color: ColorsFrave.navOrange,
        borderRadius: BorderRadius.circular(30),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.shopping_basket_outlined,
                    size: 18,
                    color: ColorsFrave.onOrange,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      context.l10n.productDetailAddToCart,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: FraveText.medium(
                        15,
                        color: ColorsFrave.onOrange,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Money.format(price),
                        maxLines: 1,
                        softWrap: false,
                        style: FraveText.medium(
                          15,
                          color: ColorsFrave.onOrange,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}