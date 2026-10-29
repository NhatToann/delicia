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
///
/// The layout is ported from the Figma UI kit frame `192:1216`
/// ("7 - A - Advertising Banner"), which is 393 x 852:
///
///   yellow band      y0..129
///   back chevron     x30 y79   (8 x 13)
///   title            x57 y79   League Spartan Medium, ink
///   heart button     x337 y79  21 x 21, orange glyph on yellow
///   sheet            y129..    #F8F8F8, 30 px top corners
///   photo            x35 y162  323 x 220, radius 20
///   price            x35 y411  orange, with the old price struck through
///   stepper          x276 / x338 y411, two 22 px orange discs
///   title            x36 y462  ink
///   rating badge     right of the title, star + score on a yellow pill
///   description      x36 y486  grey, two lines
///   size list        x35 y552…  label on the left, price on the right,
///                              radio button at x341..355
///   CTA              x103 y726  180 x 33, orange pill "Add to Cart"
///   footer           y791..852  orange bar
///
/// Every number on the screen comes from the database — the price, the
/// old price, the rating, the per-size prices — so nothing is hardcoded.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  /// The id of the selected size.
  ///
  /// Null until the product loads; then it points at the first option so
  /// the customer always has a valid selection. A product with no options
  /// keeps it null and is priced at the product's own price.
  String? _selectedOptionId;

  /// The bloc, cached so [dispose] does not have to look it up.
  ///
  /// Reading a provider from `dispose` is unsafe — the element tree is
  /// already being torn down — so the reference is captured while the
  /// widget is still mounted.
  ProductsBloc? _productsBloc;

  /// Whether the "added to cart" confirmation is currently on screen.
  ///
  /// It latches while the snack bar is visible so a double tap on the
  /// "Add to Cart" button cannot fire the confirmation twice.
  bool _addingToCart = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // The stepper lives in the cart bloc, so it has to be reset when the
      // screen opens — otherwise the quantity the customer picked for the
      // *previous* dish would still be showing.
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
      // The app-wide bottom bar — the same one the home screen uses, so
      // the navigation never changes shape between screens.
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
          // The quantity lives in the cart bloc (`selectedQuantity`), so
          // the stepper, the CTA price and the cart line all read the
          // same number — there is no second copy that can drift.
          //
          // It has to be a separate `BlocBuilder`: `context.select` is
          // illegal inside another builder's callback.
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

  /// Leaves the product-detail screen.
  ///
  /// The shared helper pops when there is somewhere to go back to and
  /// falls back to the client home otherwise, so the button always does
  /// *something* visible — even when the screen was opened directly
  /// (a deep link or a restored state).
  void _goBack() {
    if (!mounted) return;
    goBack(context);
  }

  /// Opens the cart drawer — the same overlay the home screen uses.
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

  /// Adds the dish to the cart at the currently selected size.
  ///
  /// The confirmation is shown **once per addition**:
  ///
  ///   * [_addingToCart] latches while the confirmation is on screen, so a
  ///     double tap on the CTA cannot stack two dialogs;
  ///   * the confirmation itself replaces the previous one rather than
  ///     queueing behind it.
  ///
  /// The confirmation is a light floating snack bar rather than a modal
  /// dialog: the customer has already seen the dish, the quantity and the
  /// total on the button they just pressed, and a dialog would block the
  /// screen while they are still browsing. It also auto-dismisses, so no
  /// extra "Done" tap is needed.
  void _addToCart(Productsdb product, List<String> imageRefs, int quantity) {
    // Already confirming this addition — ignore the extra tap.
    if (_addingToCart) return;

    final imageRef = imageRefs.isNotEmpty ? imageRefs.first : product.picture;
    final option = _selectedOption(product);

    context.read<CartBloc>().add(
      OnAddProductToCartEvent(
        ProductCart(
          uidProduct: product.id,
          imageProduct: imageRef,
          nameProduct: product.nameProduct,
          // The selected size carries its own price; the product price is
          // only the fallback for products without options.
          price: option?.price ?? product.price,
          quantity: quantity,
          // Figma prints the moment the dish was added on every cart row.
          addedAt: DateTime.now(),
          optionId: option?.id,
          optionLabel: option?.label,
        ),
      ),
    );

    _showAddedToCartConfirmation();
  }

  /// Shows the "added to cart" confirmation, at most once at a time.
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
                color: ColorsFrave.onOrange,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.productAddedToCart,
                  style: FraveText.medium(13, color: ColorsFrave.onOrange),
                ),
              ),
            ],
          ),
          backgroundColor: ColorsFrave.navOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1400),
        ),
      ).closed.then((_) {
        if (!mounted) return;
        setState(() => _addingToCart = false);
      });
  }

  /// The currently selected size, or null when the product has none.
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

/// Skeleton shown while the product loads.
class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    // The skeleton mirrors the loaded layout: the same system status-bar
    // inset plus the same header gap, so the screen does not jump when
    // the product arrives.
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

/// A single shimmering placeholder bar.
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

/// The loaded product: yellow header, white sheet and the orange CTA.
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
    // The price the customer actually pays: the selected size's price when
    // the dish has sizes, the product price otherwise.
    final options = product.options;
    final selected = _selectedOption(options);
    final unitPrice = selected?.price ?? product.price;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // ---- yellow header band ----
        _HeaderBand(
          title: product.nameProduct,
          productId: product.id,
          onBack: onBack,
        ),
        // ---- white sheet ----
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
                  // ---- photo ----
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
                  // ---- price + stepper ----
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
                  // ---- title + description ----
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ProductDetailGeometry.pageInset,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        // ---- title + rating ----
                        //
                        // The rating rides along with the dish name rather
                        // than sitting in the yellow header. Here the eye
                        // already goes to read the name, and the badge
                        // inherits the row's whitespace so a two-line name
                        // does not push it around.
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
                  // ---- size list ----
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
                    // The rows carry the same horizontal inset as the
                    // heading above them. Without it the label, the price
                    // and the radio sat flush against the screen edges,
                    // which looked broken next to the inset title.
                    //
                    // This also matches the Figma frame: the label starts
                    // at x35 and the radio ends at x355, i.e. 38 px from
                    // the right edge.
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
                  // ---- CTA ----
                  //
                  // The horizontal inset is derived from the available
                  // width so the pill never gets narrower than a
                  // comfortable touch target on a small phone.
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

  /// The selected option, or the first one when nothing is picked yet.
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

/// The yellow band at the top of the frame.
///
/// Figma draws the back chevron, the dish name and a heart on the yellow
/// background.
///
/// The rating used to live here too, as a small orange pill under the name.
/// Orange on yellow is a poor contrast pair and the pill read as a stray
/// blob rather than as a score, so it moved down to the dish title in the
/// white sheet — see [_RatingBadge].
class _HeaderBand extends StatelessWidget {
  const _HeaderBand({
    required this.title,
    required this.productId,
    required this.onBack,
  });

  final String title;

  /// The dish this header belongs to — the heart button needs it to know
  /// what it is marking as favourite.
  final String productId;

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // The yellow band is painted from the very top of the screen, but
    // the *content* of the header must stay clear of the status bar and
    // the notification shade. `MediaQuery.padding.top` is the height of
    // that system area, so the header's own top inset is added on top
    // of it.
    //
    // Before this, the header used a flat 16 px inset and the back
    // chevron ended up underneath the phone's clock and signal icons.
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

/// The back chevron on the yellow band.
///
/// The glyph is only 8 x 13 px — far too small to tap reliably. The
/// button is therefore padded out to a 44 x 44 touch target that is
/// centred on the glyph, so the arrow still appears exactly where Figma
/// drew it but the button is actually usable.
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

/// The heart button on the right of the yellow band.
///
/// The SVG asset already carries its own colours — a white disc with an
/// orange heart outline — so it is rendered **without** a `colorFilter`.
///
/// That filter used to be here, and it was the reason the button showed up
/// as a solid orange blob: `BlendMode.srcIn` repaints *every* opaque pixel
/// of the SVG, including the white disc behind the heart. The heart glyph
/// disappeared into a filled orange circle.
///
/// The favourite state lives in the [ProductsBloc], so the button agrees
/// with the heart shown on the home screen's product cards. Tapping it
/// dispatches [OnToggleFavoriteEvent] and confirms with a floating snack
/// bar, exactly like the home screen does.
///
/// ## Why the class is named `_FavouriteButton`
///
/// This used to be a `StatefulWidget` called `_HeartButton`, and the
/// name is kept in the comments on purpose — but the *class name* had to
/// change. Flutter's hot reload reuses the existing [Element] when the
/// widget's runtime type is unchanged, and an element that was created
/// for a `StatefulWidget` cannot be reused for a `StatelessWidget`:
/// the framework casts the old `State` to `State<StatefulWidget>` and
/// the cast fails, which paints the whole screen red with an
/// `ErrorWidget` ("Type '_HeartButtonState' is not a subtype of type
/// 'State<StatefulWidget>'").
///
/// Renaming the class changes its runtime type, so the framework
/// builds a fresh element instead of trying to recycle the old one —
/// the hot reload lands cleanly without a restart.
class _FavouriteButton extends StatelessWidget {
  const _FavouriteButton({required this.productId});

  /// The dish this button marks as favourite.
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

  /// Flips the favourite state and tells the customer it happened.
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

/// The star badge that shows the dish's rating.
///
/// It sits next to the dish name in the white sheet, not in the yellow
/// header. The header used to carry a solid orange pill with the bare
/// number, which had two problems: orange on yellow is a weak contrast
/// pair, and a number with no star next to it is easy to misread as a
/// price.
///
/// The badge now leads with a star and keeps the number in the ink
/// colour, so it reads as a score at a glance.
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

/// The dish photo — the Figma frame shows a single picture with rounded
/// corners, so a carousel is only used when the product really has more
/// than one image.
class _ProductPhoto extends StatefulWidget {
  const _ProductPhoto({
    required this.imageRefs,
    required this.fallback,
    this.discountPercent,
  });

  final List<String> imageRefs;
  final String fallback;

  /// The discount to show in the corner badge, or null when the dish is
  /// not on offer. The number comes from the product row, never from a
  /// constant in the widget.
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

    // The stack is needed even for a single photo, because the discount
    // badge floats over the picture's top-right corner.
    return Stack(
      children: <Widget>[
        photo,
        // ---- discount badge (Figma x302 y134, 56 x 56) ----
        if (widget.discountPercent != null)
          Positioned(
            top: 0,
            right: 0,
            child: DiscountBadge(percent: widget.discountPercent!),
          ),
        // ---- page dots ----
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

/// The price on the left and the quantity stepper on the right.
class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.price,
    required this.oldPrice,
    required this.quantity,
    required this.onIncrease,
    required this.onDecrease,
  });

  /// The price the customer pays for one unit.
  ///
  /// This is the **selected size's** price when the dish has sizes, and
  /// the product's own price otherwise. A price of zero means the row
  /// carries no price at all (a broken catalogue row), so the screen says
  /// so instead of rendering a misleading "0 ₫".
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
              // The "was" price only makes sense when it is really higher
              // than the current one.
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

/// The two orange discs and the number between them.
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
          // The last unit is removed from the cart by the bloc, so the
          // button stays inert at quantity 1.
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

/// One of the two round orange stepper buttons.
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

/// The orange "Add to Cart" pill.
///
/// Figma draws the pill with the label on the left and the line total on
/// the right. The total is `unit price × quantity`, and the unit price is
/// the **selected size's** price — so the number on the button always
/// matches what lands in the cart.
class _AddToCartButton extends StatelessWidget {
  const _AddToCartButton({required this.price, required this.onTap});

  /// The line total the customer will pay.
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
                  // The label is the only text in the pill, and it is kept
                  // on a single line so it never spills out of the button.
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
                  // The line total, so the customer sees what they are
                  // about to pay before tapping. It is scaled down rather
                  // than clipped so it always stays inside the pill.
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
