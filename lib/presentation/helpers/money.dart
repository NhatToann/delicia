import 'package:intl/intl.dart';

import '../../data/env/environment.dart';

/// Formats every monetary figure the app renders.
///
/// The catalogue and the Realtime Database store prices in **USD** — those
/// are the amounts that shipped with the Figma UI kit (`$8.99`, `$12.90`).
/// Vietnamese shoppers read VND, so every amount is converted with
/// [Environment.payosVndRate] — the very same rate the payOS gateway uses
/// at checkout — and rendered with the Vietnamese grouping convention
/// (`322.500 ₫`).
///
/// Keeping the stored value in USD means the Realtime Database and the
/// payOS payload stay compatible with whatever is already there; only the
/// presentation layer changes currency.
class Money {
  Money._();

  /// Rate used to turn a stored USD amount into VND.
  static int get rate => Environment.payosVndRate;

  /// Converts a stored USD amount into integer VND.
  static int toVnd(num usd) => (usd * rate).round();

  /// Vietnamese grouping: `.` separates thousands, `,` separates decimals.
  static final NumberFormat _decimal = NumberFormat.decimalPattern('vi_VN');

  /// The dong sign used as the currency suffix.
  static const String symbol = '₫';

  /// Formats a stored USD amount as VND — `12.90` becomes `322.500 ₫`.
  static String format(num usd) => '${_decimal.format(toVnd(usd))} $symbol';

  /// Formats an amount that is *already* expressed in VND.
  static String formatVnd(num vnd) =>
      '${_decimal.format(vnd.round())} $symbol';

  /// Formats a stored USD amount without the currency suffix, for the rare
  /// layout that needs the bare number (e.g. a compact price chip).
  static String formatPlain(num usd) => _decimal.format(toVnd(usd));
}
