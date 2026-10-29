import 'package:flutter/material.dart';

import '../../../../domain/models/order_record.dart';
import '../../../helpers/category_assets.dart';
import '../../../helpers/image_resolver.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// One order row for the My Orders list.
///
/// Figma node 147:2106 ("4.1.1 - C - My Orders - Active") — the row is
/// *not* a floating card; it's a flat band between two hairline
/// dividers (y211 and y345):
///
///   thumbnail   x35  y222  71.68 x 108  r20
///   title       x120 y242  League Spartan Medium 20 #391713
///   timestamp   x120 y269  League Spartan Light 14 #391713
///   item count  right-aligned at x317 y269  Light 14
///   price       right-aligned at x358 y242  Medium 20 #E95322
///   buttons     y288 h26 r100, x118 → x358
///                 Cancel Order — bg #E95322 · white · Medium 15
///                 Track Driver — bg #FFDECF · #E95322 · Regular 15
///
/// The Figma shows a single dish per order; a real order can hold
/// several, so the thumbnail is the first product and the title is the
/// first product's name.
class OrderRow extends StatelessWidget {
  const OrderRow({
    super.key,
    required this.order,
    this.onCancel,
    this.onTrack,
    this.onTap,
  });

  final OrderRecord order;

  /// Fired when the user taps "Cancel Order". The cancellation flow
  /// itself lands in a later use-case; the button is disabled until
  /// then, so this is only wired up defensively.
  final VoidCallback? onCancel;

  /// Fired when the user taps "Track Driver" — opens the live map.
  final VoidCallback? onTrack;

  /// Fired when the whole row is tapped (expands the item list).
  final VoidCallback? onTap;

  /// Figma: the divider sits at y211, the thumbnail at y222.
  static const double topGap = 10;

  /// Figma: the thumbnail ends at y330, the next divider at y345.
  static const double bottomGap = 15;

  /// Figma: the Track Driver pill is 100 px wide.
  static const double trackButtonWidth = 100;

  @override
  Widget build(BuildContext context) {
    final items = order.products;
    final thumb = items.isEmpty ? null : items.first;
    final title = thumb?.nameProduct ?? context.l10n.ordersFallbackTitle(order.id);
    final totalItems = items.fold<int>(0, (sum, i) => sum + i.quantity);
    final timestamp = _formatTimestamp(order.createdAt);
    final gutter =
        MediaQuery.sizeOf(context).width < 380 ? 20.0 : 35.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          // Figma: content starts at x35 on a 393 px frame. On narrow
          // phones the gutter shrinks so the row never overflows.
          padding: EdgeInsets.only(
            left: gutter,
            right: gutter,
            top: topGap,
            bottom: bottomGap,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  // Figma: 71.68 x 108.
                  width: 72,
                  height: 108,
                  child: thumb == null
                      ? Container(color: ColorsFrave.orangeSoft)
                      : ImageResolver.resolveWidget(
                          thumb.picture,
                          fit: BoxFit.cover,
                          fallback: CategoryAssets.pool.first,
                        ),
                ),
              ),
              // Figma: the text column starts at x120.
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Figma: the title glyphs start at y242, i.e. 20 px
                    // below the thumbnail's top edge (y222).
                    const SizedBox(height: 20),
                    // Title on the left, price on the right — Figma puts
                    // them on the same baseline (y242).
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.medium(
                              20,
                              color: ColorsFrave.ink,
                              height: 1.1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Money.format(order.amount),
                          maxLines: 1,
                          style: FraveText.medium(
                            20,
                            color: ColorsFrave.navOrange,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Timestamp on the left, item count on the right
                    // (Figma: both at y269).
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            timestamp,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.light(
                              14,
                              color: ColorsFrave.ink,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.ordersItemCount(totalItems),
                          maxLines: 1,
                          style: FraveText.light(
                            14,
                            color: ColorsFrave.ink,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    // Action row — Figma places the two pills at y288,
                    // aligned under the text column rather than the
                    // thumbnail.
                    Row(
                      children: <Widget>[
                        // Figma: the Cancel Order pill starts at x118 and
                        // is only as wide as its label.
                        Flexible(
                          child: _OrderActionButton(
                            label: context.l10n.actionCancelOrder,
                            background: ColorsFrave.navOrange,
                            foreground: ColorsFrave.onOrange,
                            isFilled: true,
                            onPressed: order.canCancel ? onCancel : null,
                          ),
                        ),
                        const Spacer(),
                        // Figma: the Track Driver pill is 100 px wide and
                        // ends at x358.
                        Flexible(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: trackButtonWidth,
                            ),
                            child: _OrderActionButton(
                              label: context.l10n.actionTrackDriver,
                              background: ColorsFrave.orangeSoft,
                              foreground: ColorsFrave.navOrange,
                              isFilled: false,
                              onPressed:
                                  order.canTrackDelivery ? onTrack : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "29 Nov, 01:20 pm" — the Figma timestamp format.
  static String _formatTimestamp(DateTime value) {
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final hh = hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final meridiem = value.hour < 12 ? 'am' : 'pm';
    return '${value.day} ${months[value.month - 1]}, '
        '$hh:$minute $meridiem';
  }
}

/// Small pill button used for "Cancel Order" / "Track Driver".
///
/// Figma: h26, r100, horizontal padding 12, League Spartan 15.
class _OrderActionButton extends StatelessWidget {
  const _OrderActionButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.isFilled,
    this.onPressed,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool isFilled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Opacity(
      // The cancel / track flows land in a later use-case, so the button
      // reads as "present but not yet live" until the handler exists.
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(100),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Container(
            height: 26,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                maxLines: 1,
                style: isFilled
                    ? FraveText.medium(15, color: foreground, height: 1.3)
                    : FraveText.regular(15, color: foreground, height: 1.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
