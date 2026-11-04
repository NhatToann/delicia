// UC-07 — DashboardBloc tests.
//
// Covers:
//   * the first batch of orders produces today's revenue / order count,
//   * the seven-day series always holds seven buckets (oldest first),
//   * the "recent orders" widget list is capped at five entries,
//   * new customers registered today are counted,
//   * a failing stream surfaces the error.

import 'package:bloc_test/bloc_test.dart';
import 'package:delicia/domain/bloc/dashboard/dashboard_bloc.dart';
import 'package:delicia/domain/models/customer_account.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_admin_services.dart';

/// The "now" every test is pinned to.
final DateTime _now = DateTime(2026, 3, 10, 14, 30);

OrderRecord _order({
  required String id,
  required double amount,
  DateTime? createdAt,
  String status = OrderRecord.statusPaidOut,
}) {
  return OrderRecord(
    id: id,
    clientId: 'u1',
    addressId: 'a1',
    street: 'Baker Street',
    reference: 'Flat 3',
    latitude: 0,
    longitude: 0,
    paymentMethod: 'CASH PAYMENT',
    amount: amount,
    status: status,
    products: const [],
    createdAt: createdAt ?? _now,
  );
}

void main() {
  group('DashboardBloc — statistics', () {
    blocTest<DashboardBloc, DashboardState>(
      'counts today revenue and the new orders',
      build: () => DashboardBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[
            _order(id: 'o1', amount: 10, createdAt: _now),
            _order(id: 'o2', amount: 5.5, createdAt: _now),
            _order(
              id: 'o3',
              amount: 100,
              createdAt: _now.subtract(const Duration(days: 2)),
            ),
          ],
        ),
        clock: () => _now,
      ),
      act: (bloc) => bloc.add(const DashboardLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.stats.todayRevenue, 15.5);
        expect(bloc.state.stats.newOrders, 2);
        expect(bloc.state.totalOrders, 3);
        expect(bloc.state.error, isNull);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'builds a seven-bucket series, oldest day first',
      build: () => DashboardBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[
            _order(id: 'o1', amount: 7, createdAt: _now),
            _order(
              id: 'o2',
              amount: 3,
              createdAt: _now.subtract(const Duration(days: 3)),
            ),
          ],
        ),
        clock: () => _now,
      ),
      act: (bloc) => bloc.add(const DashboardLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.dailyStats.length, DashboardBloc.chartDays);
        expect(bloc.state.dailyStats.first.date, DateTime(2026, 3, 4));
        expect(bloc.state.dailyStats.last.date, DateTime(2026, 3, 10));
        expect(bloc.state.dailyStats.last.revenue, 7);
        expect(bloc.state.dailyStats.last.orders, 1);
        // A day without orders is a zero bucket, not a missing one.
        expect(bloc.state.dailyStats.first.revenue, 0);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'keeps at most five recent orders',
      build: () => DashboardBloc(
        ordersService: FakeAdminOrdersService(
          orders: <OrderRecord>[
            for (var i = 1; i <= 9; i++)
              _order(id: 'o$i', amount: 1, createdAt: _now),
          ],
        ),
        clock: () => _now,
      ),
      act: (bloc) => bloc.add(const DashboardLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.recentOrders.length, DashboardBloc.recentOrdersLimit);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'counts the customers registered today',
      build: () => DashboardBloc(
        ordersService: FakeAdminOrdersService(),
        usersService: FakeAdminUsersService(
          customers: <CustomerAccount>[
            CustomerAccount(
              uid: 'c1',
              name: 'Nguyễn A',
              createdAt: DateTime(2026, 3, 10, 9),
            ),
            CustomerAccount(
              uid: 'c2',
              name: 'Trần B',
              createdAt: DateTime(2026, 3, 9, 9),
            ),
          ],
        ),
        clock: () => _now,
      ),
      act: (bloc) => bloc.add(const DashboardLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.stats.newUsers, 1);
        expect(bloc.state.stats.totalUsers, 2);
      },
    );

    blocTest<DashboardBloc, DashboardState>(
      'surfaces the stream failure',
      build: () => DashboardBloc(
        ordersService: FakeAdminOrdersService(seedError: 'firebase offline'),
        clock: () => _now,
      ),
      act: (bloc) => bloc.add(const DashboardLoadRequested()),
      wait: const Duration(milliseconds: 200),
      verify: (bloc) {
        expect(bloc.state.isLoading, isFalse);
        expect(bloc.state.error, isNotNull);
      },
    );
  });
}
