part of 'payment_bloc.dart';

@immutable
abstract class PaymentEvent {
  const PaymentEvent();
}

/// Ask the gateway for a hosted checkout page.
class OnStartPayOsPayment extends PaymentEvent {
  final double amount;
  final String orderCode;
  final String description;
  final List<ProductCart> products;
  final String returnUrl;
  final String cancelUrl;
  final String? buyerEmail;
  final String? buyerName;

  const OnStartPayOsPayment({
    required this.amount,
    required this.orderCode,
    required this.description,
    required this.products,
    required this.returnUrl,
    required this.cancelUrl,
    this.buyerEmail,
    this.buyerName,
  });
}

/// Ask the gateway whether the payment went through.
class OnVerifyPayOsPayment extends PaymentEvent {
  /// The gateway's reference for the payment. When null the bloc uses the
  /// reference it stored when the link was created.
  final String? reference;

  const OnVerifyPayOsPayment([this.reference]);
}

/// Return the bloc to its idle state — used after a successful order so a
/// second attempt starts clean.
class OnResetPaymentEvent extends PaymentEvent {
  const OnResetPaymentEvent();
}
