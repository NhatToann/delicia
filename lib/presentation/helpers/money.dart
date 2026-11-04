import 'package:intl/intl.dart';

/// Formats every monetary figure the app renders.
///
/// The catalogue, the cart and the orders all live in the Realtime
/// Database in **VND** — every product row carries `"currency": "VND"`
/// and stores its price as a whole number of dong (`75000`). Vietnamese
/// shoppers read VND, so an amount is rendered as it is stored, with the
/// Vietnamese grouping convention (`75.000 ₫`).
///
/// There is deliberately **no currency conversion anywhere in the app**:
/// the database owns the amount, the admin form edits it in the same unit
/// the customer reads, and both screens therefore always agree on what a
/// dish costs.
class Money {
  Money._();

  /// Vietnamese grouping: `.` separates thousands, `,` separates decimals.
  static final NumberFormat _decimal = NumberFormat.decimalPattern('vi_VN');

  /// The dong sign used as the currency suffix.
  static const String symbol = '₫';

  /// Formats an amount (in VND) — `75000` becomes `75.000 ₫`.
  static String format(num vnd) => '${_decimal.format(vnd.round())} $symbol';

  /// Formats an amount in VND without the currency suffix, for the rare
  /// layout that needs the bare number (e.g. a compact price chip).
  static String formatPlain(num vnd) => _decimal.format(vnd.round());

  /// Alias of [format] for call sites that spell the unit out.
  static String formatVnd(num vnd) => format(vnd);

  /// Alias of [formatPlain] for call sites that spell the unit out.
  ///
  /// This is what the admin price field shows: the **same number the
  /// customer sees** (`180.000`), not some internal unit. Admin and
  /// customer therefore always agree on what a dish costs.
  static String formatVndPlain(num vnd) => formatPlain(vnd);

  /// Returns the amount as whole dong.
  ///
  /// The database already stores whole dong, so this only rounds — there
  /// is no exchange rate involved any more.
  static int toVnd(num vnd) => vnd.round();

  /// Parses a Vietnamese-formatted amount (`180.000`, `180 000`, `180000`)
  /// into whole VND.
  ///
  /// The Vietnamese convention uses a dot as the thousands separator, so
  /// every separator is stripped and only the digits are kept. Returns
  /// `null` when the text holds no digit at all.
  static int? parseVnd(String text) {
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;
    return int.tryParse(digits);
  }
}
