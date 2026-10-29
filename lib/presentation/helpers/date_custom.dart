import 'package:flutter/material.dart';

import '../components/text_custom.dart';
import 'l10n_extension.dart';

/// Greeting + relative-time helpers used by the client home screen and
/// the order tracking card.
///
/// Everything here is Vietnamese — the copy comes from the ARB file via
/// [viL10n], because these helpers are static and have no [BuildContext]
/// to read `context.l10n` from.
class DateCustom {
  DateCustom._();

  /// Vietnamese month abbreviations, indexed by `DateTime.month - 1`.
  static const List<String> _months = <String>[
    'Thg 1', 'Thg 2', 'Thg 3', 'Thg 4', 'Thg 5', 'Thg 6',
    'Thg 7', 'Thg 8', 'Thg 9', 'Thg 10', 'Thg 11', 'Thg 12',
  ];

  /// Vietnamese weekday abbreviations, indexed by `DateTime.weekday - 1`.
  static const List<String> _weekdays = <String>[
    'Th 2', 'Th 3', 'Th 4', 'Th 5', 'Th 6', 'Th 7', 'CN',
  ];

  /// Returns the time-of-day greeting based on the device's local clock.
  static String getDateFrave() {
    final hour = DateTime.now().hour;
    final l10n = viL10n;
    if (hour >= 6 && hour < 12) return l10n.greetingMorning;
    if (hour >= 12 && hour < 18) return l10n.greetingAfternoon;
    return l10n.greetingEvening;
  }

  /// Short format for orders: "Th 3, 18 Thg 10 2026 14:30:00".
  static String getDateOrder() {
    final now = DateTime.now();
    final weekday = _weekdays[(now.weekday - 1) % 7];
    final month = _months[(now.month - 1) % 12];
    String two(int n) => n.toString().padLeft(2, '0');
    return '$weekday, ${now.day} $month ${now.year} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  /// Renders the timestamp as "Vừa xong" / "5 phút trước" / "Hôm qua" /
  /// full date.
  static String getRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    final l10n = viL10n;
    if (diff.inSeconds < 60) return l10n.timeJustNow;
    if (diff.inMinutes < 60) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays == 1) return l10n.timeYesterday;
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    final m = _months[(timestamp.month - 1) % 12];
    return '${timestamp.day} $m ${timestamp.year}';
  }

  /// Wraps the [text] widget in a [TextCustom] with the greeting prefix.
  static Widget greeting(String firstName) {
    return TextCustom(
      viL10n.greetingWithName(getDateFrave(), firstName),
      fontSize: 16,
    );
  }
}
