import 'package:delicia/presentation/helpers/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Money.format renders Vietnamese dong with dot grouping', () {
    // The database stores whole dong — `75000` is 75 000 ₫.
    expect(Money.format(75000), '75.000 ₫');
    expect(Money.format(35000), '35.000 ₫');
    expect(Money.format(0), '0 ₫');
  });

  test('Money.format renders the amount exactly as it is stored', () {
    // No currency conversion happens anywhere in the app: the number the
    // database holds is the number the customer reads.
    for (final vnd in <int>[15000, 35000, 49000, 75000, 129000, 89000]) {
      expect(Money.format(vnd), '${Money.formatPlain(vnd)} ₫');
    }
  });

  test('Money.formatVnd renders an amount already in VND', () {
    expect(Money.formatVnd(322500), '322.500 ₫');
  });

  test('Money.formatVndPlain shows the number the customer sees', () {
    expect(Money.formatVndPlain(180000), '180.000');
    expect(Money.formatVndPlain(75000), '75.000');
  });

  test('Money.formatPlain drops the currency suffix', () {
    expect(Money.formatPlain(180000), '180.000');
  });

  test('Money.parseVnd reads the Vietnamese thousands convention', () {
    expect(Money.parseVnd('180.000'), 180000);
    expect(Money.parseVnd('180 000'), 180000);
    expect(Money.parseVnd('180000'), 180000);
    expect(Money.parseVnd('180.000 ₫'), 180000);
    expect(Money.parseVnd(''), isNull);
    expect(Money.parseVnd('abc'), isNull);
  });

  test('Money.parseVnd reads back what the formatter wrote', () {
    // The admin field shows `180.000`; saving it must store `180000`.
    for (final vnd in <int>[15000, 75000, 180000, 1290000]) {
      expect(Money.parseVnd(Money.formatVndPlain(vnd)), vnd);
    }
  });
}
