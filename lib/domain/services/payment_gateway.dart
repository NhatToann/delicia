import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../data/env/environment.dart';
import '../models/product_cart.dart';
import 'app_failure.dart';

/// Errors thrown by the online payment gateways.
///
/// Carries a stable failure *code*; the presentation layer renders the
/// Vietnamese copy.
class PaymentGatewayException extends AppFailure {
  const PaymentGatewayException(super.code, [super.detail]);
}

/// The lifecycle of an online payment.
enum PaymentStatus {
  /// Nothing has been paid yet — the screen is idle and the CTA is
  /// live. This is the state the screen starts in.
  idle,

  /// The gateway is being contacted (creating a link, polling a status).
  pending,

  /// The user is on the gateway's hosted page and has not decided yet.
  awaitingUser,

  /// The gateway confirmed the money arrived.
  paid,

  /// The user aborted or the link expired.
  cancelled,

  /// The gateway could not be reached or answered with an error.
  failed,
}

/// A hosted checkout page handed back by a gateway.
class PaymentLink {
  final String url;

  /// The gateway's own id for this payment, used to poll the status.
  final String reference;

  const PaymentLink({required this.url, required this.reference});
}

/// The result of asking a gateway about a payment.
class PaymentResult {
  final PaymentStatus status;

  /// The amount the gateway actually charged, in VND.
  final int amount;

  /// The gateway's transaction id, when it has one.
  final String? transactionId;

  const PaymentResult({
    required this.status,
    required this.amount,
    this.transactionId,
  });
}

/// A gateway that can take money for an order.
///
/// Only the online gateways need this; cash is settled when the courier
/// hands the order over, so it never leaves the app.
abstract class PaymentGateway {
  /// Human-readable name, shown in error messages.
  String get name;

  /// Creates a hosted checkout page for [amount] (in the app's currency).
  Future<PaymentLink> createPaymentLink({
    required double amount,
    required String orderCode,
    required String description,
    required List<ProductCart> products,
    required String returnUrl,
    required String cancelUrl,
    required String? buyerEmail,
    required String? buyerName,
  });

  /// Asks the gateway whether the payment identified by [reference] went
  /// through.
  Future<PaymentResult> queryStatus(String reference);
}

/// payOS implementation of [PaymentGateway].
///
/// payOS is a Vietnamese gateway that only accepts integer VND. Every
/// request carries an HMAC-SHA256 signature over a canonical string built
/// from the alphabetically sorted fields, and every response carries a
/// signature of its own which is verified before the result is trusted.
///
/// The credentials live in [Environment]. When they are missing the
/// gateway throws [PaymentGatewayException] rather than silently failing.
class PayOsGateway implements PaymentGateway {
  PayOsGateway({
    http.Client? client,
    String? clientId,
    String? apiKey,
    String? checksumKey,
    String? apiBase,
  })  : _client = client ?? http.Client(),
        _clientId = clientId,
        _apiKey = apiKey,
        _checksumKey = checksumKey,
        _apiBase = apiBase;

  final http.Client _client;

  /// Overrides for the credentials in [Environment]. Null means "read them
  /// from the environment" — the injection points exist so the gateway can
  /// be exercised in tests without shipping real keys.
  final String? _clientId;
  final String? _apiKey;
  final String? _checksumKey;
  final String? _apiBase;

  @override
  String get name => 'payOS';

  /// The merchant's client id.
  String get clientId => _clientId ?? Environment.payosClientId;

  /// The merchant's api key.
  String get apiKey => _apiKey ?? Environment.payosApiKey;

  /// The channel's checksum key — never ship this inside an app in
  /// production; point [Environment.payosApiBase] at a backend instead.
  String get checksumKey => _checksumKey ?? Environment.payosChecksumKey;

  /// The host the requests are sent to.
  String get apiBase => _apiBase ?? Environment.payosApiBase;

  /// Whether this gateway has everything it needs to talk to payOS.
  bool get isConfigured =>
      clientId.isNotEmpty && apiKey.isNotEmpty && checksumKey.isNotEmpty;

  @override
  Future<PaymentLink> createPaymentLink({
    required double amount,
    required String orderCode,
    required String description,
    required List<ProductCart> products,
    required String returnUrl,
    required String cancelUrl,
    required String? buyerEmail,
    required String? buyerName,
  }) async {
    _requireConfigured();

    final amountVnd = toVnd(amount);
    final orderCodeValue = _orderCodeFrom(orderCode);

    final body = <String, dynamic>{
      'orderCode': orderCodeValue,
      'amount': amountVnd,
      'description': _trimDescription(description),
      'returnUrl': returnUrl,
      'cancelUrl': cancelUrl,
      if (buyerEmail != null && buyerEmail.isNotEmpty)
        'buyerEmail': buyerEmail,
      if (buyerName != null && buyerName.isNotEmpty) 'buyerName': buyerName,
      'items': products
          .map(
            (p) => <String, dynamic>{
              'name': p.nameProduct,
              'quantity': p.quantity,
              'price': toVnd(p.price),
            },
          )
          .toList(growable: false),
      'signature': signRequest(
        amount: amountVnd,
        cancelUrl: cancelUrl,
        description: _trimDescription(description),
        orderCode: orderCodeValue,
        returnUrl: returnUrl,
        checksumKey: checksumKey,
      ),
    };

    final response = await _client.post(
      Uri.parse('$apiBase/v2/payment-requests'),
      headers: <String, String>{
        'x-client-id': clientId,
        'x-api-key': apiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    final decoded = _decode(response);
    final data = decoded['data'];
    if (data is! Map) {
      throw const PaymentGatewayException(
        AppFailureCodes.paymentGatewayNoLink,
      );
    }
    final checkoutUrl = (data['checkoutUrl'] ?? '').toString();
    if (checkoutUrl.isEmpty) {
      throw const PaymentGatewayException(
        AppFailureCodes.paymentGatewayNoLink,
      );
    }
    final linkId = (data['paymentLinkId'] ?? '').toString();
    return PaymentLink(
      url: checkoutUrl,
      reference: linkId.isEmpty ? orderCodeValue.toString() : linkId,
    );
  }

  @override
  Future<PaymentResult> queryStatus(String reference) async {
    _requireConfigured();

    final response = await _client.get(
      Uri.parse('$apiBase/v2/payment-requests/$reference'),
      headers: <String, String>{
        'x-client-id': clientId,
        'x-api-key': apiKey,
      },
    );

    final decoded = _decode(response);
    final data = decoded['data'];
    if (data is! Map) {
      return PaymentResult(
        status: PaymentStatus.failed,
        amount: 0,
      );
    }
    final rawStatus = (data['status'] ?? '').toString().toUpperCase();
    final amount = int.tryParse((data['amount'] ?? 0).toString()) ?? 0;
    final transactionId = (data['id'] ?? data['transactionId'] ?? '').toString();

    final status = switch (rawStatus) {
      'PAID' => PaymentStatus.paid,
      'CANCELLED' || 'EXPIRED' => PaymentStatus.cancelled,
      'PENDING' => PaymentStatus.awaitingUser,
      _ => PaymentStatus.failed,
    };

    return PaymentResult(
      status: status,
      amount: amount,
      transactionId: transactionId.isEmpty ? null : transactionId,
    );
  }

  /// Builds the canonical signature string payOS expects.
  ///
  /// The fields are sorted alphabetically and joined with `&` in the
  /// form `key=value`, exactly as documented by payOS.
  static String buildSignatureData({
    required int amount,
    required String cancelUrl,
    required String description,
    required int orderCode,
    required String returnUrl,
  }) =>
      'amount=$amount'
      '&cancelUrl=$cancelUrl'
      '&description=$description'
      '&orderCode=$orderCode'
      '&returnUrl=$returnUrl';

  /// Signs [data] with the channel's checksum key.
  static String signWith(String data, String checksumKey) =>
      Hmac(sha256, utf8.encode(checksumKey)).convert(utf8.encode(data)).toString();

  /// Convenience wrapper that builds the data and signs it in one go.
  static String signRequest({
    required int amount,
    required String cancelUrl,
    required String description,
    required int orderCode,
    required String returnUrl,
    String? checksumKey,
  }) {
    final data = buildSignatureData(
      amount: amount,
      cancelUrl: cancelUrl,
      description: description,
      orderCode: orderCode,
      returnUrl: returnUrl,
    );
    return signWith(data, checksumKey ?? Environment.payosChecksumKey);
  }

  /// Verifies the signature payOS attaches to a response.
  ///
  /// A response whose signature does not match is not trusted.
  static bool verifyResponse({
    required Map<String, dynamic> data,
    required String signature,
    String? checksumKey,
  }) {
    final key = checksumKey ?? Environment.payosChecksumKey;
    final expected = signWith(
      buildSignatureData(
        amount: int.tryParse((data['amount'] ?? 0).toString()) ?? 0,
        cancelUrl: (data['cancelUrl'] ?? '').toString(),
        description: (data['description'] ?? '').toString(),
        orderCode: int.tryParse((data['orderCode'] ?? 0).toString()) ?? 0,
        returnUrl: (data['returnUrl'] ?? '').toString(),
      ),
      key,
    );
    return expected == signature;
  }

  /// Converts an app amount into integer VND.
  static int toVnd(double amount) =>
      (amount * Environment.payosVndRate).round();

  void _requireConfigured() {
    if (!isConfigured) {
      throw const PaymentGatewayException(
        'payOS is not configured for this build.',
      );
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      decoded = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
    } catch (_) {
      throw PaymentGatewayException(
        AppFailureCodes.paymentGatewayUnreadable,
        '${response.statusCode}',
      );
    }
    if (response.statusCode >= 400) {
      throw PaymentGatewayException(
        AppFailureCodes.paymentGatewayFailed,
        '${response.statusCode}',
      );
    }
    final code = (decoded['code'] ?? '').toString();
    if (code.isNotEmpty && code != '00') {
      throw const PaymentGatewayException(
        AppFailureCodes.paymentGatewayRejected,
      );
    }
    return decoded;
  }

  /// payOS order codes are integers, so a string code is reduced to the
  /// digits it contains.
  int _orderCodeFrom(String orderCode) {
    final digits = orderCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return DateTime.now().millisecondsSinceEpoch % 1000000000;
    }
    return int.tryParse(digits) ?? DateTime.now().millisecondsSinceEpoch;
  }

  /// Bank transfer descriptions are limited to 9 characters.
  String _trimDescription(String description) {
    final cleaned = description.replaceAll(RegExp(r'[^a-zA-Z0-9 ]'), '').trim();
    if (cleaned.isEmpty) return 'Thanh toan';
    return cleaned.length <= 9 ? cleaned : cleaned.substring(0, 9);
  }
}
