/// The itemised money breakdown of an order, in whole VND.
///
/// The app is **cash on delivery**: the courier collects the money at the
/// door, so the amount the customer was quoted and the amount the courier
/// collects have to be the exact same number. That is only possible if
/// every component is rounded **once, at the moment it is produced**, and
/// the total is then a plain sum of whole dong — never a second rounding
/// of an already-rounded sum.
///
/// Concretely: `tax = subtotal * 0.05` and `fee = km * 5000` are both
/// fractional. Rounding only the total would make the printed tax line,
/// the printed fee line and the printed total disagree by a dong or two,
/// and the courier would collect a different number from the one on the
/// customer's screen.
///
/// Every field is an `int` (whole dong) by construction. The database
/// stores whole dong too, so a persisted breakdown round-trips exactly.
class PriceBreakdown {
  /// Sum of the line items, before tax and delivery.
  final int subtotal;

  /// Service tax on [subtotal] (5 %).
  final int tax;

  /// Voucher discount, in whole dong. 0 when no voucher applies.
  ///
  /// The tax is computed on the *discounted* subtotal, so the discount has
  /// to be tracked separately for the printed lines to add up to the
  /// printed total.
  final int discount;

  /// Distance-based delivery fee (0 when the destination is under 1 km or
  /// when a free-shipping voucher applies).
  final int delivery;

  /// What the customer pays: [subtotal] + [tax] + [delivery] − [discount].
  final int total;

  const PriceBreakdown({
    required this.subtotal,
    required this.tax,
    required this.discount,
    required this.delivery,
    required this.total,
  });

  /// Builds a breakdown from fractional inputs.
  ///
  /// Each component is rounded on its own (half away from zero, which is
  /// what [num.round] does), then the total is the sum of the rounded
  /// parts — so the printed lines always add up to the printed total.
  ///
  /// [deliveryFee] may be negative? No: pass 0 for "no delivery fee".
  factory PriceBreakdown.from({
    required double subtotal,
    required double tax,
    required double deliveryFee,
    double discount = 0,
  }) {
    final roundedSubtotal = subtotal.round();
    final roundedTax = tax.round();
    final roundedDelivery = deliveryFee.round();
    final roundedDiscount = discount.round();
    return PriceBreakdown(
      subtotal: roundedSubtotal,
      tax: roundedTax,
      discount: roundedDiscount,
      delivery: roundedDelivery,
      total: roundedSubtotal + roundedTax + roundedDelivery - roundedDiscount,
    );
  }

  /// A breakdown with no tax and no delivery fee.
  factory PriceBreakdown.subtotalOnly(double subtotal) =>
      PriceBreakdown.from(subtotal: subtotal, tax: 0, deliveryFee: 0);

  /// The same breakdown with a different delivery fee.
  ///
  /// Used when a voucher zeroes the shipping cost — the customer pays the
  /// new fee, the courier is still paid the original one.
  PriceBreakdown withDelivery(int newDelivery) => PriceBreakdown(
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        delivery: newDelivery,
        total: subtotal + tax + newDelivery - discount,
      );

  /// The same breakdown with a discounted subtotal.
  ///
  /// The tax is recomputed on the discounted subtotal, so a voucher never
  /// leaves a stale tax line behind.
  PriceBreakdown withSubtotal(double newSubtotal, {required double taxRate}) =>
      PriceBreakdown.from(
        subtotal: newSubtotal,
        tax: newSubtotal * taxRate,
        deliveryFee: delivery.toDouble(),
        discount: discount.toDouble(),
      );

  /// Map form for the Realtime Database.
  Map<String, dynamic> toMap() => <String, dynamic>{
        'subtotal': subtotal,
        'tax': tax,
        'discount': discount,
        'deliveryFee': delivery,
        'total': total,
      };

  /// Reads a persisted breakdown.
  ///
  /// Missing or unparsable components fall back to 0 — an order written
  /// before the breakdown existed still parses.
  factory PriceBreakdown.fromMap(Map<dynamic, dynamic> map) {
    int read(String key) {
      final raw = map[key];
      if (raw is num) return raw.round();
      return int.tryParse(raw?.toString() ?? '') ?? 0;
    }

    final subtotal = read('subtotal');
    final tax = read('tax');
    final discount = read('discount');
    final delivery = read('deliveryFee');
    final total = read('total');
    return PriceBreakdown(
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      delivery: delivery,
      // A stored total of 0 on a non-empty order means the row predates
      // the breakdown — recompute it rather than charging the customer 0.
      total: total != 0 ? total : subtotal + tax + delivery - discount,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PriceBreakdown &&
          other.subtotal == subtotal &&
          other.tax == tax &&
          other.discount == discount &&
          other.delivery == delivery &&
          other.total == total;

  @override
  int get hashCode => Object.hash(subtotal, tax, discount, delivery, total);

  @override
  String toString() =>
      'PriceBreakdown(subtotal: $subtotal, tax: $tax, discount: $discount, '
      'delivery: $delivery, total: $total)';
}
