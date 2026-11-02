import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../domain/models/order_filter.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The Vietnamese empty-state copy of a filter.
///
/// The domain enum keeps its English `emptySubtitle`; only what the user
/// reads is translated.
String _emptySubtitle(BuildContext context, OrderFilter filter) {
  switch (filter) {
    case OrderFilter.active:
      return context.l10n.ordersEmptyActiveSubtitle;
    case OrderFilter.completed:
      return context.l10n.ordersEmptyCompletedSubtitle;
    case OrderFilter.cancelled:
      return context.l10n.ordersEmptyCancelledSubtitle;
  }
}

/// Empty state for the My Orders screen.
///
/// Figma node 147:2153 ("4.1.1 - B - My Orders"):
///
///   icon     "Transfer Document icon" 140.65 x 167 at x≈201 y343
///            (stroke #FFDECF, 11.16 px, rounded)
///   copy     "You don't have any active orders at this time"
///            League Spartan Medium 30 · #E95322 · centred · y551
///
/// The copy is filter-aware: the Figma only documents the active
/// wording, the other two follow the same shape.
class OrdersEmptyState extends StatelessWidget {
  const OrdersEmptyState({super.key, required this.filter, this.onAction});

  final OrderFilter filter;

  /// Optional call-to-action shown under the copy. The Figma frame has no
  /// button, so the caller decides whether to offer one.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 35),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Figma: 140.65 x 167. The SVG's own viewBox is
                // slightly wider, so the tight box keeps the Figma
                // size and the picture scales inside it.
                SizedBox(
                  width: 140,
                  height: 167,
                  child: SvgPicture.asset(
                    'assets/figma_home/orders_empty_icon.svg',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 46),
                // Figma wraps the copy into three lines — "You don't have
                // any" / "active orders at this" / "time" — so the text
                // block is capped at the width of the widest of those
                // lines. On narrow phones the cap is relaxed and the
                // copy simply wraps differently.
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 255),
                  child: Text(
                    _emptySubtitle(context, filter),
                    textAlign: TextAlign.center,
                    style: FraveText.medium(
                      30,
                      color: ColorsFrave.navOrange,
                      height: 1.08,
                    ),
                  ),
                ),
                if (onAction != null) ...<Widget>[
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: onAction,
                    style: FilledButton.styleFrom(
                      backgroundColor: ColorsFrave.navOrange,
                      foregroundColor: ColorsFrave.onOrange,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      context.l10n.ordersEmptyActiveCta,
                      maxLines: 1,
                      style: FraveText.medium(15, color: ColorsFrave.onOrange),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                // Figma puts the illustration at y337 and the copy at
                // y551 — the group sits above the vertical centre of the
                // content area. The column is centred, so trailing
                // space lifts the whole group to the Figma position.
                const SizedBox(height: 68),
              ],
            ),
          ),
        );
      },
    );
  }
}
