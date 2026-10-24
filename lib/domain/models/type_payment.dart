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

  const TypePaymentMethod({
    required this.uid,
    required this.type,
    required this.icon,
    required this.color,
  });
}

final List<TypePaymentMethod> typePaymentMethods = [
  TypePaymentMethod(
    uid: 'CREDIT_CARD',
    type: 'CREDIT CARD',
    icon: Icons.credit_card,
    color: const Color(0xFF1977F3),
  ),
  TypePaymentMethod(
    uid: 'CASH',
    type: 'CASH PAYMENT',
    icon: Icons.payments_outlined,
    color: const Color(0xFF22A45D),
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

/// Default payment method selected in [CheckoutScreen].
final TypePaymentMethod defaultPaymentMethod = typePaymentMethods[1];