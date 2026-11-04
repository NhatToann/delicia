import 'package:delicia/data/env/environment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CartPricing distance-based delivery fee', () {
    test('under 1km is free shipping (0 VND)', () {
      expect(CartPricing.deliveryFeeVnd(0.0), 0.0);
      expect(CartPricing.deliveryFeeVnd(0.5), 0.0);
      expect(CartPricing.deliveryFeeVnd(0.99), 0.0);
    });

    test('1km to 3km is 5,000 VND / km', () {
      expect(CartPricing.deliveryFeeVnd(1.0), 5000.0);
      expect(CartPricing.deliveryFeeVnd(2.0), 10000.0);
      expect(CartPricing.deliveryFeeVnd(2.5), 12500.0);
      expect(CartPricing.deliveryFeeVnd(3.0), 15000.0);
    });

    test('3km to 8km is 8,000 VND / km', () {
      expect(CartPricing.deliveryFeeVnd(3.1), 3.1 * 8000.0);
      expect(CartPricing.deliveryFeeVnd(5.0), 40000.0);
      expect(CartPricing.deliveryFeeVnd(8.0), 64000.0);
    });

    test('above 8km is 10,000 VND / km', () {
      expect(CartPricing.deliveryFeeVnd(8.1), 8.1 * 10000.0);
      expect(CartPricing.deliveryFeeVnd(10.0), 100000.0);
      expect(CartPricing.deliveryFeeVnd(15.5), 155000.0);
    });

    test('totalOf includes dynamic delivery fee when provided', () {
      const subtotal = 20000.0;
      const tax = 20000.0 * 0.05; // 1,000

      // Default delivery fee if omitted
      expect(
        CartPricing.totalOf(subtotal),
        subtotal + tax + CartPricing.deliveryFee,
      );

      // Custom delivery fee (e.g. 0 for free shipping)
      expect(CartPricing.totalOf(subtotal, delivery: 0.0), subtotal + tax);

      // Custom distance-based delivery fee
      final feeVnd = CartPricing.deliveryFeeVnd(2.0); // 10,000 VND
      expect(
        CartPricing.totalOf(subtotal, delivery: feeVnd),
        subtotal + tax + feeVnd,
      );
    });
  });
}
