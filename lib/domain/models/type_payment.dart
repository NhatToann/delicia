import 'package:flutter/material.dart';

/// Canonical list of payment methods supported by the checkout flow
/// (UC-04). Mirrors the original Frave `TypePaymentMethod` model so any
/// other code in the project (e.g. order detail, admin) can refer to
/// the same constants.
class TypePaymentMethod {
  final String uid;
  final String type;
  final IconData icon;
  final Color color;

  /// Optional path to a vector asset that reproduces the Figma glyph
  /// for this method. When set it wins over [icon].
  final String? asset;

  /// Whether this method needs a third-party gateway (and therefore an
  /// external checkout page) before the order can be created.
  final bool requiresGateway;

  const TypePaymentMethod({
    required this.uid,
    required this.type,
    required this.icon,
    required this.color,
    this.asset,
    this.requiresGateway = false,
  });
}

final List<TypePaymentMethod> typePaymentMethods = [
  TypePaymentMethod(
    uid: 'CREDIT_CARD',
    type: 'CREDIT CARD',
    icon: Icons.credit_card,
    color: const Color(0xFF1977F3),
    // Figma node `286:1862` draws the card method with the kit's own
    // "Card icon" glyph.
    asset: 'assets/figma_payment/card_icon.svg',
  ),
  TypePaymentMethod(
    uid: 'CASH',
    type: 'CASH PAYMENT',
    icon: Icons.payments_outlined,
    color: const Color(0xFF22A45D),
    // Cash uses the kit's own "Cash icon" glyph, drawn on the same
    // 33.2392 x 23.4538 canvas as the card icon.
    asset: 'assets/figma_payment/cash_icon.svg',
  ),
  TypePaymentMethod(
    uid: 'PAYPAL',
    type: 'PAYPAL',
    icon: Icons.account_balance_wallet_outlined,
    color: const Color(0xFF003087),
  ),
  TypePaymentMethod(
    uid: 'GOOGLE_PAY',
    type: 'GOOGLE PAY',
    icon: Icons.account_balance_outlined,
    color: const Color(0xFF4285F4),
  ),
  TypePaymentMethod(
    uid: 'MERCADO_PAGO',
    type: 'MERCADO PAGO',
    icon: Icons.shopping_bag_outlined,
    color: const Color(0xFF00B1EA),
  ),
];

/// Default payment method selected in the Payment screen.
///
/// Cash is the default: it needs no gateway, so the order can be created
/// the instant the user taps "Pay Now".
final TypePaymentMethod defaultPaymentMethod = typePaymentMethods[1];

/// The payOS gateway method.
///
/// It is only offered when [Environment.payosConfigured] is true — see
/// `lib/data/env/environment.dart`.
const TypePaymentMethod payOsPaymentMethod = TypePaymentMethod(
  uid: 'PAYOS',
  type: 'PAYOS',
  icon: Icons.qr_code_scanner_rounded,
  color: Color(0xFFEE2B7B),
  requiresGateway: true,
);
