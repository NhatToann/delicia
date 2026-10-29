import 'package:delicia/presentation/helpers/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Money.format renders Vietnamese dong with dot grouping', () {
    // 12.90 USD at 25 000 VND/USD = 322 500 VND.
    expect(Money.format(12.90), '322.500 ₫');
    expect(Money.format(8.99), '224.750 ₫');
    expect(Money.format(0), '0 ₫');
  });

  test('Money.formatVnd renders an amount already in VND', () {
    expect(Money.formatVnd(322500), '322.500 ₫');
  });

  test('Money.toVnd rounds to whole dong', () {
    expect(Money.toVnd(1), 25000);
    expect(Money.toVnd(0.00002), 1);
  });
}
