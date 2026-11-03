import 'package:intl/intl.dart';

/// Formats every monetary figure the app renders.
///
/// Database stores prices directly in VND (e.g. 75000 for 75.000 đ).
class Money {
  Money._();

  /// Vietnamese grouping: `.` separates thousands, `,` separates decimals.
  static final NumberFormat _decimal = NumberFormat.decimalPattern('vi_VN');

  /// The dong sign used as the currency suffix.
  static const String symbol = '₫';

  /// Formats a stored amount as VND — `75000` becomes `75.000 ₫`.
  static String format(num vnd) =>
      '${_decimal.format(vnd.round())} $symbol';

  /// Alias for format to maintain compatibility.
  static String formatVnd(num vnd) => format(vnd);

  /// Formats an amount without the currency suffix (e.g. for a compact price chip).
  static String formatPlain(num vnd) => _decimal.format(vnd.round());

  /// Returns the rounded VND amount.
  static int toVnd(num vnd) => vnd.round();
}