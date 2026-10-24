import 'package:flutter/material.dart';

import '../components/text_custom.dart';

/// Greeting + relative-time helpers used by the client home screen and
/// the order tracking card.
class DateCustom {
  DateCustom._();

  /// Returns "Good morning" / "Good afternoon" / "Good evening" based on
  /// the device's local clock. Original Frave implementation.
  static String getDateFrave() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 12) return 'Good morning';
    if (hour >= 12 && hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  /// Short format for orders: "Mon, 18 Oct 2026 14:30:00".
  static String getDateOrder() {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
    ];
    final weekday = weekdays[(now.weekday - 1) % 7];
    final month = months[(now.month - 1) % 12];
    String two(int n) => n.toString().padLeft(2, '0');
    return '$weekday, ${now.day} $month ${now.year} '
        '${two(now.hour)}:${two(now.minute)}:${two(now.second)}';
  }

  /// Renders the timestamp as "5m ago" / "2h ago" / "Yesterday" / full date.
  static String getRelativeTime(DateTime timestamp) {
    final diff = DateTime.now().difference(timestamp);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final m = months[(timestamp.month - 1) % 12];
    return '${timestamp.day} $m ${timestamp.year}';
  }

  /// Wraps the [text] widget in a [TextCustom] with the greeting prefix.
  static Widget greeting(String firstName) {
    return TextCustom(
      '${getDateFrave()}, $firstName',
      fontSize: 16,
    );
  }
}