part of 'payment_bloc.dart';

@immutable
class PaymentState {
  /// Where the payment currently stands.
  final PaymentStatus status;

  /// The hosted checkout page the gateway handed back. The screen opens
  /// it in an external browser.
  final String? checkoutUrl;

  /// The gateway's reference for the payment, used when verifying.
  final String? reference;

  /// The gateway's transaction id, once the payment is confirmed.
  final String? transactionId;

  /// The last error. Null while everything is fine. Carries a stable code
  /// the UI can translate.
  final AppFailure? error;

  const PaymentState({
    this.status = PaymentStatus.idle,
    this.checkoutUrl,
    this.reference,
    this.transactionId,
    this.error,
  });

  /// True while the gateway is being contacted.
  bool get isBusy =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.awaitingUser;

  PaymentState copyWith({
    PaymentStatus? status,
    String? checkoutUrl,
    String? reference,
    String? transactionId,
    AppFailure? error,
    bool clearError = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      checkoutUrl: checkoutUrl ?? this.checkoutUrl,
      reference: reference ?? this.reference,
      transactionId: transactionId ?? this.transactionId,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
