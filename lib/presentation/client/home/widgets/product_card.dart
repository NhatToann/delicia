import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/bloc/products/products_bloc.dart';
import '../../../../domain/models/product.dart';
import '../../../helpers/category_assets.dart';
import '../../../helpers/image_resolver.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import '../../product_detail/widgets/price_label.dart';
import '../../search/widgets/highlighted_text.dart';

/// ProductCard — card showing a single product (image + name + price).
/// Material Design 3 style following UI Kit guidelines.
///
/// Overflow defence: this card is dropped into a `childAspectRatio` grid
/// (search = 0.68, home menu = 0.72), so its height is decided by the grid
/// and not by us. The old version hard-coded `Padding(all: 14)` plus a
/// fixed 15 px two-line title, an 8 px gap and a 34 px price row inside
/// `Expanded(flex: 3)`. On a 393 px phone that left only ~68 px of usable
/// height for ~78 px of content, which painted the yellow "BOTTOM
/// OVERFLOWED BY 19 px" stripe across every card.
///
/// Two changes kill it permanently:
///   1. Tighter padding and a smaller title / price row, so the natural
///      content height fits inside the reserved block.
///   2. A `LayoutBuilder` + `FittedBox` net: when the grid hands us even
///      less room (narrow phones, large text scale, 3-line titles), the
///      whole text block scales down instead of overflowing.
class ProductCard extends StatelessWidget {
  final Productsdb product;
  final VoidCallback onTap;

  /// When set, every occurrence of this query inside the product name is
  /// highlighted. Pass the raw search query; the card handles the
  /// accent-insensitive matching.
  final String? highlightQuery;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.highlightQuery,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ColorsFrave.surfaceColor,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ---- Product image ----
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ImageResolver.resolveWidget(
                    product.picture,
                    fit: BoxFit.cover,
                    fallback: CategoryAssets.pool.first,
                  ),
                  // Price chip, top-left, Figma-like pill.
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      height: 20,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: ColorsFrave.navOrange,
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: PriceLabel(
                          product: product,
                          size: 12,
                          color: ColorsFrave.onOrange,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                  // Real favourite toggle, not a static glyph.
                  Positioned(
                    top: 6,
                    right: 6,
                    child: _FavoriteButton(product: product),
                  ),
                  // Rating chip, bottom-left.
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: _RatingChip(product: product),
                  ),
                ],
              ),
            ),

            // ---- Product info ----
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: _buildTitle(),
                        ),
                        const SizedBox(height: 4),
                        // Price row: the add button is a fixed 28 px, the
                        // price shrinks if the column is narrow.
                        SizedBox(
                          height: 28,
                          child: Row(
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: PriceLabel(
                                    product: product,
                                    size: 15,
                                    color: ColorsFrave.navOrange,
                                    weight: FontWeight.w700,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              _AddButton(product: product),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The product title, with the search terms highlighted when the card is
  /// rendered inside the search results.
  Widget _buildTitle() {
    final titleStyle = FraveText.semiBold(
      13,
      color: ColorsFrave.darkText,
      height: 1.2,
    );
    final query = highlightQuery?.trim() ?? '';
    if (query.isEmpty) {
      return Text(
        product.nameProduct,
        style: titleStyle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return HighlightedText(
      text: product.nameProduct,
      query: query,
      style: titleStyle,
      maxLines: 2,
    );
  }
}

/// Small white pill with the product's real star rating.
class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.product});
  final Productsdb product;

  @override
  Widget build(BuildContext context) {
    if (!product.hasRating) return const SizedBox.shrink();
    return Container(
      height: 16,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 10, color: Colors.amber.shade700),
          const SizedBox(width: 2),
          Text(
            product.rating.toStringAsFixed(1),
            style: FraveText.regular(10, height: 1),
          ),
        ],
      ),
    );
  }
}

/// Favourite toggle backed by [ProductsBloc]. Reads `state.favorites` so the
/// icon is never hard-coded, and dispatches `OnToggleFavoriteEvent` on tap.
class _FavoriteButton extends StatelessWidget {
  const _FavoriteButton({required this.product});
  final Productsdb product;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProductsBloc, ProductsState>(
      buildWhen: (a, b) =>
          a.favorites.contains(product.id) !=
          b.favorites.contains(product.id),
      builder: (context, state) {
        final isFav = state.favorites.contains(product.id);
        return Semantics(
          button: true,
          label: isFav
              ? context.l10n.homeRemoveProductFromFavourites(product.nameProduct)
              : context.l10n.homeAddProductToFavourites(product.nameProduct),
          child: Material(
            color: ColorsFrave.surfaceColor.withValues(alpha: 0.92),
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => context
                  .read<ProductsBloc>()
                  .add(OnToggleFavoriteEvent(product.id)),
              child: SizedBox(
                width: 30,
                height: 30,
                child: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  size: 17,
                  color: isFav
                      ? ColorsFrave.navOrange
                      : ColorsFrave.greyText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Orange gradient "+" button. Tapping adds the product straight to the cart.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.product});
  final Productsdb product;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.homeAddProductToCart(product.nameProduct),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: ColorsFrave.primaryGradient,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.add,
          size: 18,
          color: ColorsFrave.onPrimary,
        ),
      ),
    );
  }
}