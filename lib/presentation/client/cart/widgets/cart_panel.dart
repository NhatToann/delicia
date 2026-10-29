import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../domain/bloc/cart/cart_bloc.dart';
import '../../../../domain/models/product_cart.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';
import 'cart_empty_state.dart';
import 'cart_item_row.dart';
import 'cart_summary.dart';

/// The orange cart drawer from Figma nodes `202:2213` (4.3 - A) and
/// `202:1358` (4.3 - B).
///
/// The panel component is `259:5412` ("Menu Slide / Cart"), 330 px wide and
/// 861 px tall. The 393 x 852 Figma frame places its top-left corner at
/// (66, -10), so the panel bleeds 10 px off the top of the frame and the
/// status bar sits on top of it.
///
/// Every offset below is a **frame** coordinate, i.e. the position the
/// content has on the 393 x 852 screen:
///
///   panel fill `#E95322`, left corners r80
///   icon       40.3 x 40.3 white rounded square at x179 y66
///   title      "Cart" League Spartan Bold 24 `#F8F8F8` at x230 y76
///   rule       yellow `#F5CB58` hairline at x101 y145, 254 x 1  (Line 1)
///   subtitle   League Spartan Medium 20 `#F8F8F8`, centred at y165
///              "Your cart is empty" (4.3 - A)
///              "You have N items in the cart" (4.3 - B)
///   items      one [CartItemRow] per product, 80 x 80 thumbnails at x99
///              (first row y209, second row y321)
///   dividers   peach `#FFDECF` hairlines at y304 / y416  (Line 2 / Line 3)
///   summary    Subtotal / Tax and Fees / Delivery / Total
///   CTA        yellow pill "Checkout" 131 x 36 at x164 y720
///
/// The body scrolls when the list is long; the Checkout button stays pinned
/// so it is always reachable.
class CartPanel extends StatelessWidget {
  const CartPanel({super.key, this.onCheckout});

  /// Fired when the user taps the Checkout button.
  final VoidCallback? onCheckout;

  /// Horizontal inset of the panel header, measured from the Figma frame
  /// (10.61 % of the 330 px panel).
  static const double contentInset = 35;

  /// Inset used by the item rows (Figma x33, panel-local).
  static const double rowInset = 33;

  /// Right inset of the item rows and the summary (Figma x293, panel-local).
  static const double rowRightInset = 37;

  /// Top of the header icon (Figma frame y66).
  static const double headerTop = 66;

  /// Height of the header icon square.
  static const double iconSize = 40.3;

  /// Distance from the header icon to the yellow rule (Figma y145).
  static const double ruleGap = 38.85;

  /// Distance from the yellow rule to the subtitle (Figma y165).
  static const double subtitleGap = 18.85;

  /// Height of the subtitle line.
  static const double subtitleHeight = 22;

  /// Total height of the header block — where the scrollable body starts.
  static const double headerHeight =
      headerTop + iconSize + ruleGap + 1 + subtitleGap + subtitleHeight;

  /// Top of the first item row (Figma frame y209).
  static const double firstRowTop = 209;

  /// Distance between the header and the first row.
  static const double listTop = firstRowTop - headerHeight;

  /// Distance between two item rows.
  ///
  /// Figma puts the second thumbnail at y321, so the rows are 112 px apart.
  /// A row is 80 px tall, which leaves 32 px for the peach divider and the
  /// gap below it.
  static const double rowPitch = 112;

  /// Distance from the bottom of a row to the peach divider.
  static const double dividerGap = 15;

  /// Height of the peach divider that closes a row.
  static const double dividerHeight = 1;

  /// Distance from the bottom of a row to the next row.
  static const double rowGap = rowPitch - 80 - dividerGap - dividerHeight;

  /// Distance from the last divider to the summary block (Figma y476).
  static const double summaryTop = 59;

  /// Distance from the bottom of the screen to the bottom of the Checkout
  /// button (Figma y720 + 36 = 756, so 96 px of orange below it).
  static const double ctaBottomInset = 96;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartBloc, CartState>(
      builder: (context, state) {
        final products = state.products ?? const <ProductCart>[];
        final isEmpty = products.isEmpty;

        return Material(
          color: ColorsFrave.navOrange,
          // Only the two left corners are rounded — the panel is flush to the
          // right edge of the screen, exactly like `menu_bg.svg`.
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(80),
            bottomLeft: Radius.circular(80),
          ),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: false,
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _PanelHeader(
                  subtitle: isEmpty
                      ? context.l10n.cartEmpty
                      : context.l10n.cartItemsInCart(products.length),
                ),
                Expanded(
                  child: isEmpty
                      ? const CartEmptyState()
                      : _PopulatedBody(
                          products: products,
                          subtotal: state.total,
                          onCheckout: onCheckout,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// "Cart" title + basket glyph, the yellow hairline rule and the subtitle.
///
/// The icon and the title form a single group that Figma centres inside the
/// panel, so the row is centred rather than left-aligned. The subtitle is
/// centred too — in both frames it sits on the panel's centre line.
class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.subtitle});

  /// The line under the rule: "Your cart is empty" or
  /// "You have N items in the cart".
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: CartPanel.headerTop),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // 40.3 x 40.3 white rounded square holding the basket glyph.
                Container(
                  width: CartPanel.iconSize,
                  height: CartPanel.iconSize,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: ColorsFrave.onOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SvgPicture.asset(
                    'assets/figma_cart/cart_basket.svg',
                    width: 24.78,
                    height: 26,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(width: 10.7),
                Text(
                  context.l10n.cartTitle,
                  style: FraveText.bold(
                    24,
                    color: ColorsFrave.onOrange,
                    height: 26 / 24,
                  ),
                ),
              ],
            ),
          ),
          // Figma "Line 1": a 1 px yellow rule 254 px wide, inset 35.
          const SizedBox(height: CartPanel.ruleGap),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: CartPanel.contentInset,
            ),
            child: Container(height: 1, color: ColorsFrave.headerYellow),
          ),
          const SizedBox(height: CartPanel.subtitleGap),
          SizedBox(
            height: CartPanel.subtitleHeight,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: FraveText.medium(
                20,
                color: ColorsFrave.onOrange,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The populated body: the scrollable item list, the summary and the pinned
/// Checkout button.
class _PopulatedBody extends StatelessWidget {
  const _PopulatedBody({
    required this.products,
    required this.subtotal,
    this.onCheckout,
  });

  final List<ProductCart> products;
  final double subtotal;
  final VoidCallback? onCheckout;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CartBloc>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        // The list scrolls; the summary sits below it in the same scroll
        // view so a long cart can still reach the totals.
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              CartPanel.rowInset,
              CartPanel.listTop,
              CartPanel.rowRightInset,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (var i = 0; i < products.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(height: CartPanel.rowGap),
                  CartItemRow(
                    // The key has to include the selected size — the same
                    // dish in two sizes is two different rows.
                    key: ValueKey(products[i].lineKey),
                    product: products[i],
                    addedAt: products[i].addedAt,
                    onIncrease: () =>
                        bloc.add(OnIncreaseQuantityProductToCartEvent(i)),
                    // The bloc drops the line when the quantity reaches
                    // zero, so tapping "−" on the last unit removes it.
                    onDecrease: () =>
                        bloc.add(OnDecreaseProductQuantityToCartEvent(i)),
                    onDelete: () => bloc.add(OnDeleteProductToCartEvent(i)),
                  ),
                  const SizedBox(height: CartPanel.dividerGap),
                  // Figma "Line 2" / "Line 3": a peach hairline below every
                  // cart row.
                  Container(
                    height: CartPanel.dividerHeight,
                    color: ColorsFrave.orangeSoft,
                  ),
                ],
                const SizedBox(height: CartPanel.summaryTop),
                CartSummary(subtotal: subtotal),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        // Pinned CTA — always reachable no matter how long the cart is.
        // Figma places it 96 px above the bottom of the frame.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            CartPanel.contentInset,
            8,
            CartPanel.contentInset,
            CartPanel.ctaBottomInset,
          ),
          child: _CheckoutButton(onTap: onCheckout),
        ),
      ],
    );
  }
}

/// The yellow "Checkout" pill (Figma node `291:6301`).
///
/// Figma draws it 131 x 36 with a 30 px radius, centred in the panel.
class _CheckoutButton extends StatelessWidget {
  const _CheckoutButton({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 131,
        height: 36,
        child: Material(
          color: ColorsFrave.headerYellow,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  context.l10n.actionCheckout,
                  maxLines: 1,
                  softWrap: false,
                  textAlign: TextAlign.center,
                  style: FraveText.medium(
                    24,
                    color: ColorsFrave.navOrange,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
