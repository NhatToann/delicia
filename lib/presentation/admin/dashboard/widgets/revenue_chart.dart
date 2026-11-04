import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../domain/models/daily_stat.dart';
import '../../../helpers/l10n_extension.dart';
import '../../../helpers/money.dart';
import '../../../themes/colors_frave.dart';
import '../../../themes/type_frave.dart';

/// The seven-day revenue bar chart of the admin dashboard (UC-07).
///
/// The series is drawn with `fl_chart`'s [BarChart]: one bar per day,
/// oldest day first, so the newest day sits on the right — the same
/// reading order as the label row underneath.
///
/// The chart is deliberately axis-light: the y axis carries no numbers
/// (the numbers live in the tiles above), only the day initials. A
/// dashboard tile has to be readable at a glance, and a full grid of
/// labels would compete with the bars.
class RevenueChart extends StatelessWidget {
  const RevenueChart({
    super.key,
    required this.dailyStats,
    this.height = 180,
  });

  /// The seven days, oldest first.
  final List<DailyStat> dailyStats;

  /// The height of the chart area.
  final double height;

  /// The weekday initials — one letter, one day.
  static const List<String> _weekdayInitials = <String>[
    'T2',
    'T3',
    'T4',
    'T5',
    'T6',
    'T7',
    'CN',
  ];

  /// The weekday initial of [date].
  ///
  /// `DateTime.weekday` is 1 (Monday) … 7 (Sunday); the list is indexed
  /// from the same origin.
  static String weekdayInitial(DateTime date) =>
      _weekdayInitials[(date.weekday - 1) % 7];

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            context.l10n.adminChartEmpty,
            style: FraveText.regular(14, color: ColorsFrave.greyText),
          ),
        ),
      );
    }

    final maxRevenue = dailyStats.fold<double>(
      0,
      (max, stat) => stat.revenue > max ? stat.revenue : max,
    );

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: _maxY(maxRevenue),
          minY: 0,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= dailyStats.length) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(
                      weekdayInitial(dailyStats[index].date),
                      style: FraveText.regular(
                        11,
                        color: ColorsFrave.greyText,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < dailyStats.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: dailyStats[i].revenue,
                    width: 14,
                    color: ColorsFrave.navOrange,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  /// A headroom factor so the tallest bar does not touch the top edge.
  static double _maxY(double maxRevenue) {
    if (maxRevenue <= 0) return 1;
    return maxRevenue * 1.2;
  }
}

/// A compact bar chart of the daily *order count*.
///
/// The dashboard shows both numbers — money and volume — and they tell
/// different stories: a day with many small orders and a day with few
/// large ones look the same on a revenue chart.
class OrderCountChart extends StatelessWidget {
  const OrderCountChart({super.key, required this.dailyStats, this.height = 120});

  final List<DailyStat> dailyStats;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (dailyStats.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            context.l10n.adminChartEmpty,
            style: FraveText.regular(14, color: ColorsFrave.greyText),
          ),
        ),
      );
    }

    final maxOrders = dailyStats.fold<int>(
      0,
      (max, stat) => stat.orders > max ? stat.orders : max,
    );

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxOrders + 1).toDouble(),
          minY: 0,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(
            topTitles: AxisTitles(),
            rightTitles: AxisTitles(),
            leftTitles: AxisTitles(),
            bottomTitles: AxisTitles(),
          ),
          barGroups: <BarChartGroupData>[
            for (var i = 0; i < dailyStats.length; i++)
              BarChartGroupData(
                x: i,
                barRods: <BarChartRodData>[
                  BarChartRodData(
                    toY: dailyStats[i].orders.toDouble(),
                    width: 10,
                    color: ColorsFrave.secondaryColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// The headline number of the revenue chart — used by the card title.
class RevenueChartTotal extends StatelessWidget {
  const RevenueChartTotal({super.key, required this.revenue});

  final double revenue;

  @override
  Widget build(BuildContext context) => Text(
    Money.format(revenue),
    style: FraveText.bold(20, color: ColorsFrave.ink),
  );
}
