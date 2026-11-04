import 'package:delicia/domain/models/price_breakdown.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the money breakdown that the cash-on-delivery
/// checkout persists on every order.
///
/// The app is COD: the courier collects the money at the door. The number
/// printed on the customer's screen must therefore be *exactly* the number
/// the courier asks for — a single dong of drift is a real dispute at the
/// door.
///
/// The rules these tests lock down:
///
///  * Every component is rounded **once**, at the moment it is produced.
///  * The total is the sum of the rounded parts — never a second rounding.
///  * The printed lines always add up to the printed total.
///  * A breakdown survives a database round-trip unchanged.
void main() {
  group('PriceBreakdown.from', () {
    test('rounds each component once and sums the rounded parts', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 12345.6,
        tax: 617.28,
        deliveryFee: 15000.4,
      );

      expect(breakdown.subtotal, 12346);
      expect(breakdown.tax, 617);
      expect(breakdown.delivery, 15000);
      // The total is the sum of the *rounded* parts, not a rounding of the
      // raw sum (12345.6 + 617.28 + 15000.4 = 27963.28 -> 27963).
      expect(breakdown.total, 12346 + 617 + 15000);
      expect(breakdown.total, 27963);
    });

    test('the printed lines add up to the printed total', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 99999.99,
        tax: 4999.9995,
        deliveryFee: 12345.67,
      );

      expect(
        breakdown.subtotal + breakdown.tax + breakdown.delivery -
            breakdown.discount,
        breakdown.total,
      );
    });

    test('a discount lowers the total but leaves the other lines alone', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 15000,
        discount: 25000,
      );

      expect(breakdown.subtotal, 100000);
      expect(breakdown.tax, 5000);
      expect(breakdown.delivery, 15000);
      expect(breakdown.discount, 25000);
      expect(breakdown.total, 95000);
    });

    test('a zero subtotal yields a zero total', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 0,
        tax: 0,
        deliveryFee: 0,
      );
      expect(breakdown.total, 0);
    });
  });

  group('PriceBreakdown.subtotalOnly', () {
    test('drops both tax and delivery', () {
      final breakdown = PriceBreakdown.subtotalOnly(50000);
      expect(breakdown.subtotal, 50000);
      expect(breakdown.tax, 0);
      expect(breakdown.delivery, 0);
      expect(breakdown.total, 50000);
    });
  });

  group('PriceBreakdown.withDelivery', () {
    test('a free-shipping voucher zeroes the fee line', () {
      final original = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 20000,
      );
      final free = original.withDelivery(0);

      expect(free.delivery, 0);
      expect(free.total, original.total - 20000);
      expect(free.subtotal, original.subtotal);
      expect(free.tax, original.tax);
    });
  });

  group('PriceBreakdown.withSubtotal', () {
    test('recomputes the tax on the discounted subtotal', () {
      final original = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 20000,
      );
      final discounted = original.withSubtotal(90000, taxRate: 0.05);

      expect(discounted.subtotal, 90000);
      expect(discounted.tax, 4500);
      expect(discounted.delivery, 20000);
      expect(discounted.total, 114500);
    });
  });

  group('PriceBreakdown persistence', () {
    test('survives a database round-trip unchanged', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 150000,
        tax: 7500,
        deliveryFee: 32000,
      );
      final restored = PriceBreakdown.fromMap(breakdown.toMap());

      expect(restored, breakdown);
      expect(restored.total, breakdown.total);
    });

    test('a discount survives the round-trip', () {
      final breakdown = PriceBreakdown.from(
        subtotal: 150000,
        tax: 7500,
        deliveryFee: 32000,
        discount: 15000,
      );
      final restored = PriceBreakdown.fromMap(breakdown.toMap());

      expect(restored.discount, 15000);
      expect(restored, breakdown);
    });

    test('an order written before the breakdown existed still parses', () {
      final restored = PriceBreakdown.fromMap(<String, dynamic>{
        'subtotal': 80000,
        'tax': 4000,
        'deliveryFee': 15000,
      });

      expect(restored.total, 99000);
    });

    test('a stored total of 0 is recomputed, not trusted', () {
      final restored = PriceBreakdown.fromMap(<String, dynamic>{
        'subtotal': 80000,
        'tax': 4000,
        'deliveryFee': 15000,
        'total': 0,
      });

      expect(restored.total, 99000);
    });

    test('malformed components fall back to 0 instead of throwing', () {
      final restored = PriceBreakdown.fromMap(<String, dynamic>{
        'subtotal': 'not-a-number',
        'tax': null,
        'deliveryFee': '12000',
      });

      expect(restored.subtotal, 0);
      expect(restored.tax, 0);
      expect(restored.delivery, 12000);
      expect(restored.total, 12000);
    });
  });

  group('PriceBreakdown equality', () {
    test('two breakdowns with the same numbers are equal', () {
      final a = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 15000,
      );
      final b = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 15000,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('a different total makes them unequal', () {
      final a = PriceBreakdown.from(
        subtotal: 100000,
        tax: 5000,
        deliveryFee: 15000,
      );
      final b = a.withDelivery(0);

      expect(a, isNot(b));
    });
  });
}
