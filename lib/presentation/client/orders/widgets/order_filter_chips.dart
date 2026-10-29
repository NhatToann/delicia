import 'package:flutter/material.dart';

import '../../../../domain/models/order_filter.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The Vietnamese label of a filter chip.
///
/// The domain enum only exposes a stable `id`; everything the user reads
/// comes from `context.l10n`.
String _filterLabel(BuildContext context, OrderFilter filter) {
  switch (filter) {
    case OrderFilter.active:
      return context.l10n.ordersFilterActive;
    case OrderFilter.completed:
      return context.l10n.ordersFilterCompleted;
    case OrderFilter.cancelled:
      return context.l10n.ordersFilterCancelled;
  }
}

/// Filter chip row for the My Orders screen.
///
/// Figma node 147:2106 (My Orders — Active) and 147:2153 (My Orders):
/// three pills at y164, 28 px tall, 38 px radius, 104 px wide, spread
/// evenly across the 393 px frame:
///
///   Active      bg #E95322 · white text · League Spartan Medium 17
///   Completed   bg #FFDECF · #E95322 text · League Spartan Regular 17
///   Cancelled   bg #FFDECF · #E95322 text · League Spartan Regular 17
///
/// Only one chip is filled at a time; the other two stay on the soft
/// orange fill. Tapping a chip switches the visible order list.
class OrderFilterChips extends StatelessWidget {
  const OrderFilterChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  /// The filter currently shown by the list below.
  final OrderFilter selected;

  /// Fired when the user taps a different chip.
  final ValueChanged<OrderFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Figma: the three pills are 104 px wide, sitting at x35..139,
    // x144..248 and x253..357 — i.e. 5 px apart, spanning the same
    // 323 px content width as the order rows.
    final gutter =
        MediaQuery.sizeOf(context).width < 380 ? 20.0 : 35.0;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutter),
      child: Row(
        children: <Widget>[
          for (final filter in OrderFilter.values) ...<Widget>[
            if (filter != OrderFilter.values.first)
              const SizedBox(width: 5),
            Expanded(
              child: _FilterChip(
                key: ValueKey<String>('filter-chip-${filter.id}'),
                label: _filterLabel(context, filter),
                isSelected: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: '$label ${context.l10n.ordersFilterLabelSuffix}',
      // Own the semantics node: the chip's own label ("Hoàn tất bộ lọc")
      // must win over the visible text ("Hoàn tất") so assistive tech —
      // and the widget tests — can target it.
      container: true,
      excludeSemantics: true,
      child: Material(
        color: isSelected ? ColorsFrave.navOrange : ColorsFrave.orangeSoft,
        borderRadius: BorderRadius.circular(38),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Figma: h28, r100, horizontal padding 12 around the label.
          // The whole pill (padding included) is scaled down when the
          // screen is too narrow or the text scale is large, so the row
          // can never overflow.
          child: SizedBox(
            height: 28,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: isSelected
                        ? FraveText.medium(
                            17,
                            color: ColorsFrave.onOrange,
                            height: 1.2,
                          )
                        : FraveText.regular(
                            17,
                            color: ColorsFrave.navOrange,
                            height: 1.2,
                          ),
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
