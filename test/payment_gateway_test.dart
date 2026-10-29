// Tests for the payOS gateway.
//
// The gateway is the only piece of the payment flow that talks to the
// network, so its signature construction and its status mapping are
// pinned here with a stubbed HTTP client.

import 'dart:convert';

import 'package:delicia/domain/models/product_cart.dart';
import 'package:delicia/domain/services/payment_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const ProductCart _shake = ProductCart(
  uidProduct: 'p1',
  imageProduct: 'assets/figma_home/card_best_1.png',
  nameProduct: 'Strawberry Shake',
  price: 20.00,
  quantity: 2,
);

void main() {
  group('PayOsGateway signature', () {
    test('builds the canonical alphabetically sorted string', () {
      final data = PayOsGateway.buildSignatureData(
        amount: 50000,
        cancelUrl: 'https://app.test/cancel',
        description: 'Thanh toan',
        orderCode: 1234,
        returnUrl: 'https://app.test/success',
      );
      expect(
        data,
        'amount=50000'
        '&cancelUrl=https://app.test/cancel'
        '&description=Thanh toan'
        '&orderCode=1234'
        '&returnUrl=https://app.test/success',
      );
    });

    test('produces a stable HMAC-SHA256 digest', () {
      const key = 'checksum-key';
      const data = 'amount=50000&orderCode=1234';
      // The digest is a 64 char hex string.
      expect(PayOsGateway.signWith(data, key).length, 64);
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(PayOsGateway.signWith(data, key)),
        isTrue,
      );
      // Signing is deterministic.
      expect(
        PayOsGateway.signWith(data, key),
        PayOsGateway.signWith(data, key),
      );
    });

    test('a different key produces a different digest', () {
      const data = 'amount=50000&orderCode=1234';
      expect(
        PayOsGateway.signWith(data, 'a'),
        isNot(PayOsGateway.signWith(data, 'b')),
      );
    });

    test('verifies a response signature and rejects a tampered one', () {
      final data = <String, dynamic>{
        'amount': 50000,
        'cancelUrl': 'https://app.test/cancel',
        'description': 'Thanh toan',
        'orderCode': 1234,
        'returnUrl': 'https://app.test/success',
      };
      final signature = PayOsGateway.signWith(
        PayOsGateway.buildSignatureData(
          amount: 50000,
          cancelUrl: 'https://app.test/cancel',
          description: 'Thanh toan',
          orderCode: 1234,
          returnUrl: 'https://app.test/success',
        ),
        'checksum-key',
      );
      expect(
        PayOsGateway.verifyResponse(
          data: data,
          signature: signature,
          checksumKey: 'checksum-key',
        ),
        isTrue,
      );
      expect(
        PayOsGateway.verifyResponse(
          data: data,
          signature: 'deadbeef',
          checksumKey: 'checksum-key',
        ),
        isFalse,
      );
    });
  });

  group('PayOsGateway requests', () {
    test('sends the signed body and returns the checkout url', () async {
      late http.Request captured;
      final gateway = PayOsGateway(
        clientId: 'client-id',
        apiKey: 'api-key',
        checksumKey: 'checksum-key',
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'code': '00',
              'desc': 'success',
              'data': <String, dynamic>{
                'checkoutUrl': 'https://pay.payos.vn/web/abc',
                'paymentLinkId': 'abc',
                'amount': 50000,
              },
            }),
            200,
          );
        }),
      );

      // The credentials come from the environment, so the test injects
      // them through the same constants the gateway reads.
      final link = await gateway.createPaymentLink(
        amount: 2.0,
        orderCode: '2026102412345',
        description: 'Delicia order',
        products: <ProductCart>[_shake],
        returnUrl: 'https://app.test/success',
        cancelUrl: 'https://app.test/cancel',
        buyerEmail: 'a@b.test',
        buyerName: 'Test User',
      );

      expect(link.url, 'https://pay.payos.vn/web/abc');
      expect(link.reference, 'abc');

      final body = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(body['orderCode'], 2026102412345);
      expect(body['returnUrl'], 'https://app.test/success');
      expect(body['cancelUrl'], 'https://app.test/cancel');
      expect(body['buyerEmail'], 'a@b.test');
      expect(body['signature'], isNotEmpty);
      expect((body['items'] as List<dynamic>).length, 1);
    });

    test('maps the gateway status onto the payment status', () async {
      Future<PaymentGateway> gatewayWith(String status) async {
        return PayOsGateway(
          clientId: 'client-id',
          apiKey: 'api-key',
          checksumKey: 'checksum-key',
          client: MockClient((request) async {
            return http.Response(
              jsonEncode(<String, dynamic>{
                'code': '00',
                'desc': 'success',
                'data': <String, dynamic>{
                  'status': status,
                  'amount': 50000,
                  'id': 'tx-1',
                },
              }),
              200,
            );
          }),
        );
      }

      final paid = await (await gatewayWith('PAID')).queryStatus('abc');
      expect(paid.status, PaymentStatus.paid);
      expect(paid.transactionId, 'tx-1');

      final pending = await (await gatewayWith('PENDING')).queryStatus('abc');
      expect(pending.status, PaymentStatus.awaitingUser);

      final cancelled = await (await gatewayWith('CANCELLED')).queryStatus('abc');
      expect(cancelled.status, PaymentStatus.cancelled);
    });

    test('converts the app amount into VND', () {
      expect(PayOsGateway.toVnd(2.0), 50000);
      expect(PayOsGateway.toVnd(1.5), 37500);
    });
  });
}
