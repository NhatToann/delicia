import 'package:delicia/data/env/environment.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/utils/driver_earnings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DriverEarnings and CartPricing driver earnings', () {
    test('CartPricing driverEarningsVnd gives 90% of shipping fee', () {
      // Under 1km -> 5,000 VND
      expect(CartPricing.driverEarningsVnd(0.5), 5000.0);

      // 2km -> 10,000 VND shipping fee -> 9,000 VND earnings
      expect(CartPricing.driverEarningsVnd(2.0), 9000.0);

      // 5km -> 40,000 VND shipping fee -> 36,000 VND earnings
      expect(CartPricing.driverEarningsVnd(5.0), 36000.0);

      // 10km -> 100,000 VND shipping fee -> 90,000 VND earnings
      expect(CartPricing.driverEarningsVnd(10.0), 90000.0);
    });

    test('DriverEarnings calculates earnings from order coordinates', () {
      final orderNear = OrderRecord(
        id: 'ord-near',
        clientId: 'c1',
        addressId: 'a1',
        street: 'Near restaurant',
        reference: '',
        latitude: Environment.restaurantLatitude + 0.001,
        longitude: Environment.restaurantLongitude + 0.001,
        paymentMethod: 'CASH',
        amount: 10.0,
        status: OrderRecord.statusPaidOut,
        products: const [],
        createdAt: DateTime.now(),
      );

      // Distance is ~0.15 km (< 1km) -> minimum 5,000 VND
      expect(DriverEarnings.earningsVndForOrder(orderNear), 5000.0);

      // Fallback for (0, 0) coordinates: defaults to 1km -> 5,000 VND * 0.9 = 4,500 VND
      final orderZeroCoords = OrderRecord(
        id: 'ord-zero',
        clientId: 'c2',
        addressId: 'a2',
        street: 'No coords',
        reference: '',
        latitude: 0,
        longitude: 0,
        paymentMethod: 'CASH',
        amount: 10.0,
        status: OrderRecord.statusPaidOut,
        products: const [],
        createdAt: DateTime.now(),
      );
      expect(DriverEarnings.earningsVndForOrder(orderZeroCoords), 4500.0);
    });
  });
}
