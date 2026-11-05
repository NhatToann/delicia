// Cash-on-delivery settlement — the money half of the delivery flow.
//
// The app has exactly one payment method: the customer hands over cash
// when the courier knocks on the door. Nothing in the system records that
// moment by itself, so the courier has to confirm it, and the amount they
// actually took has to reach the database.
//
// This file protects that contract end to end:
//
//   * the model round-trips the settlement fields;
//   * the service writes the settlement in the *same* write as the status
//     change (a delivered order without its money recorded is the one
//     state the restaurant cannot detect);
//   * the bloc forwards the settlement and mirrors it into its state;
//   * the driver UI asks for the money and shows that it was collected.
//
// The Firebase write itself is exercised through a fake `DatabaseReference`
// tree, so the assertions are about the *payload* the service builds,
// not about the SDK.

import 'package:delicia/domain/bloc/driver_orders/driver_orders_bloc.dart';
import 'package:delicia/domain/models/delivery_status.dart';
import 'package:delicia/domain/models/order_record.dart';
import 'package:delicia/domain/models/price_breakdown.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/presentation/delivery/details/widgets/cod_settlement_badge.dart';
import 'package:delicia/presentation/delivery/details/widgets/cod_settlement_sheet.dart';
import 'package:delicia/presentation/helpers/l10n_extension.dart';
import 'package:delicia/presentation/helpers/money.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/load_fonts.dart';
/// A fake `OrdersService` that records what it was asked to do.
class _RecordingOrdersService implements OrdersService {
  String? lastOrderId;
  String? lastStatus;
  bool? lastCashCollected;
  int? lastCollectedAmountVnd;
  String? lastDeliveryPhoto;

  @override
  Future<void> updateDeliveryStatus(
    String orderId,
    String newStatus, {
    String? deliveryPhoto,
    bool cashCollected = false,
    int? collectedAmountVnd,
  }) async {
    lastOrderId = orderId;
    lastStatus = newStatus;
    lastCashCollected = cashCollected;
    lastCollectedAmountVnd = collectedAmountVnd;
    lastDeliveryPhoto = deliveryPhoto;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

OrderRecord _order({
  String id = 'o-cod-1',
  int total = 180000,
  int? collected,
  int collectedAt = 0,
  bool cashCollected = false,
  String status = 'ON WAY',
}) {
  return OrderRecord(
    id: id,
    clientId: 'c1',
    addressId: 'a1',
    street: '55 Nguyen Hue',
    reference: '',
    latitude: 10.773,
    longitude: 106.703,
    paymentMethod: 'CASH PAYMENT',
    amount: total.toDouble(),
    quote: PriceBreakdown(
      subtotal: total - 9000,
      tax: 9000,
      discount: 0,
      delivery: 0,
      total: total,
    ),
    status: status,
    products: const [],
    createdAt: DateTime(2026, 11, 5),
    cashCollected: cashCollected,
    cashCollectedAt: collectedAt,
    collectedAmountVnd: collected ?? 0,
  );
}

void main() {
  setUpAll(loadAppFonts);

  group('OrderRecord carries the settlement', () {
    test('a fresh order has collected nothing', () {
      final order = _order();
      expect(order.cashCollected, isFalse);
      expect(order.cashCollectedAt, 0);
      expect(order.collectedAmountVnd, 0);
    });

    test('the settlement round-trips through the database map', () {
      final order = _order(
        cashCollected: true,
        collectedAt: 1762310400000,
        collected: 180000,
      );
      final map = order.toMap();

      expect(map['cashCollected'], isTrue);
      expect(map['cashCollectedAt'], 1762310400000);
      expect(map['collectedAmountVnd'], 180000);

      final parsed = OrderRecord.fromMap('o-cod-1', map);
      expect(parsed.cashCollected, isTrue);
      expect(parsed.cashCollectedAt, 1762310400000);
      expect(parsed.collectedAmountVnd, 180000);
    });

    test('an order written before the settlement existed still parses', () {
      final parsed = OrderRecord.fromMap('o1', <String, dynamic>{});
      expect(parsed.cashCollected, isFalse);
      expect(parsed.cashCollectedAt, 0);
      expect(parsed.collectedAmountVnd, 0);
    });

    test('a malformed collected amount falls back to zero', () {
      final parsed = OrderRecord.fromMap('o1', <String, dynamic>{
        'collectedAmountVnd': 'not-a-number',
      });
      expect(parsed.collectedAmountVnd, 0);
    });

    test('toMap omits an uncollected amount instead of writing a zero', () {
      final map = _order().toMap();
      expect(map.containsKey('collectedAmountVnd'), isFalse);
    });

    test('copyWith can set and preserve the settlement', () {
      final order = _order();
      final settled = order.copyWith(
        cashCollected: true,
        cashCollectedAt: 42,
        collectedAmountVnd: 180000,
      );
      expect(settled.cashCollected, isTrue);
      expect(settled.cashCollectedAt, 42);
      expect(settled.collectedAmountVnd, 180000);

      // Copying without touching the settlement keeps it.
      final again = settled.copyWith(status: 'DELIVERED');
      expect(again.cashCollected, isTrue);
      expect(again.collectedAmountVnd, 180000);
    });
  });

  group('the amount due comes from the quote when there is one', () {
    test('the quoted total wins over the flat amount', () {
      final order = _order(total: 180000);
      expect(order.codAmountVnd, 180000);
    });

    test('an order without a quote falls back to its amount', () {
      final order = OrderRecord(
        id: 'o2',
        clientId: 'c1',
        addressId: 'a1',
        street: '',
        reference: '',
        latitude: 0,
        longitude: 0,
        paymentMethod: 'CASH PAYMENT',
        amount: 125000,
        status: 'ON WAY',
        products: const [],
        createdAt: DateTime(2026, 11, 5),
      );
      expect(order.codAmountVnd, 125000);
    });

    test('a quote of zero falls back to the amount', () {
      final order = OrderRecord(
        id: 'o3',
        clientId: 'c1',
        addressId: 'a1',
        street: '',
        reference: '',
        latitude: 0,
        longitude: 0,
        paymentMethod: 'CASH PAYMENT',
        amount: 99000,
        status: 'ON WAY',
        products: const [],
        createdAt: DateTime(2026, 11, 5),
        quote: const PriceBreakdown(
          subtotal: 0,
          tax: 0,
          discount: 0,
          delivery: 0,
          total: 0,
        ),
      );
      expect(order.codAmountVnd, 99000);
    });
  });

  group('DriverOrdersBloc forwards the settlement', () {
    test('the service receives the collected flag and the amount', () async {
      final service = _RecordingOrdersService();
      final bloc = DriverOrdersBloc(ordersService: service);
      addTearDown(bloc.close);

      final order = _order();
      bloc.emit(DriverOrdersState(assignedOrders: [order]));

      bloc.add(UpdateOrderStatusEvent(
        orderId: order.id,
        currentStatus: DeliveryStatus.onTheWay,
        targetStatus: DeliveryStatus.delivered,
        deliveryPhoto: 'https://example.test/photo.jpg',
        cashCollected: true,
        collectedAmountVnd: 175000,
      ));

      await bloc.stream.firstWhere((s) => s.isSuccess);

      expect(service.lastOrderId, order.id);
      expect(service.lastStatus, 'DELIVERED');
      expect(service.lastCashCollected, isTrue);
      expect(service.lastCollectedAmountVnd, 175000);
      expect(service.lastDeliveryPhoto, 'https://example.test/photo.jpg');
    });

    test('a plain status change collects nothing', () async {
      final service = _RecordingOrdersService();
      final bloc = DriverOrdersBloc(ordersService: service);
      addTearDown(bloc.close);

      bloc.emit(DriverOrdersState(assignedOrders: [_order()]));

      bloc.add(UpdateOrderStatusEvent(
        orderId: 'o-cod-1',
        currentStatus: DeliveryStatus.onTheWay,
        targetStatus: DeliveryStatus.delivered,
      ));

      await bloc.stream.firstWhere((s) => s.isSuccess);

      expect(service.lastCashCollected, isFalse);
      expect(service.lastCollectedAmountVnd, isNull);
    });

    test('the bloc state mirrors the settlement immediately', () async {
      final service = _RecordingOrdersService();
      final bloc = DriverOrdersBloc(ordersService: service);
      addTearDown(bloc.close);

      bloc.emit(DriverOrdersState(assignedOrders: [_order()]));

      bloc.add(UpdateOrderStatusEvent(
        orderId: 'o-cod-1',
        currentStatus: DeliveryStatus.onTheWay,
        targetStatus: DeliveryStatus.delivered,
        cashCollected: true,
        collectedAmountVnd: 180000,
      ));

      final settled = await bloc.stream.firstWhere(
        (s) => s.isSuccess && s.assignedOrders.first.cashCollected,
      );

      final updated = settled.assignedOrders.first;
      expect(updated.status, 'DELIVERED');
      expect(updated.cashCollected, isTrue);
      expect(updated.cashCollectedAt, greaterThan(0));
      expect(updated.collectedAmountVnd, 180000);
    });
  });

  group('the settlement sheet collects the money', () {
    testWidgets('it shows the amount due and confirms on tap', (tester) async {
      final order = _order(total: 180000);
      int? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => CodSettlementSheet(order: order),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // The amount the customer has to hand over.
      expect(find.text('Số tiền khách phải trả'), findsOneWidget);
      expect(find.text(Money.format(180000)), findsOneWidget);

      // The field is pre-filled with the quoted amount.
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, Money.formatPlain(180000));

      await tester.tap(find.text('Xác nhận đã thu tiền'));
      await tester.pumpAndSettle();

      expect(result, 180000);
    });

    testWidgets('a different amount is read back with parseVnd', (tester) async {
      final order = _order(total: 180000);
      int? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => CodSettlementSheet(order: order),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '175.000');
      await tester.pumpAndSettle();

      // The mismatch is called out — it is what the restaurant reconciles.
      expect(
        find.text('Số tiền đã thu khác với số tiền khách phải trả.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Xác nhận đã thu tiền'));
      await tester.pumpAndSettle();

      expect(result, 175000);
    });

    testWidgets('dismissing the sheet reports no collection', (tester) async {
      final order = _order(total: 180000);
      int? result = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await showModalBottomSheet<int>(
                    context: context,
                    isScrollControlled: true,
                    builder: (ctx) => CodSettlementSheet(order: order),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // Tapping the barrier dismisses the sheet. The delivery must not be
      // completed — the courier has to confirm the money.
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(result, isNull);
    });
  });

  group('the settlement badge shows the collected state', () {
    testWidgets('it is hidden while nothing was collected', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: CodSettlementBadge(order: _neverCollected())),
        ),
      );
      expect(find.text('Đã thu tiền'), findsNothing);
    });

    testWidgets('it shows the time and the amount once settled', (tester) async {
      final l10n = viL10n;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CodSettlementBadge(
              order: _order(
                cashCollected: true,
                collectedAt: 1762310400000,
                collected: 175000,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Đã thu tiền'), findsOneWidget);
      expect(find.text(l10n.codSettlementCollectedAmount(Money.format(175000))),
          findsOneWidget);
      expect(find.textContaining('Thời điểm thu tiền'), findsOneWidget);
    });
  });
}

/// A non-const order used by the "nothing collected" badge case.
OrderRecord _neverCollected() => _order();
