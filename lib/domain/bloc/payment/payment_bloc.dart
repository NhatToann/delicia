import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/product_cart.dart';
import '../../services/app_failure.dart';
import '../../services/payment_gateway.dart';

part 'payment_event.dart';
part 'payment_state.dart';

/// PaymentBloc — drives the online-gateway leg of the Payment screen.
///
/// Cash never reaches this bloc: it is settled when the courier hands the
/// order over, so the screen creates the order directly. Only a method
/// that needs a hosted checkout page (payOS) goes through here:
///
///   1. [OnStartPayOsPayment] asks the gateway for a checkout link and
///      emits [PaymentState.awaitingPayment] with the URL to open.
///   2. [OnVerifyPayOsPayment] asks the gateway whether the money arrived
///      and emits [PaymentState.paid] or [PaymentState.failed].
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc({required PaymentGateway gateway})
      : _gateway = gateway,
        super(const PaymentState()) {
    on<OnStartPayOsPayment>(_onStart);
    on<OnVerifyPayOsPayment>(_onVerify);
    on<OnResetPaymentEvent>(_onReset);
  }

  final PaymentGateway _gateway;

  Future<void> _onStart(
    OnStartPayOsPayment event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.pending, clearError: true));
    try {
      final link = await _gateway.createPaymentLink(
        amount: event.amount,
        orderCode: event.orderCode,
        description: event.description,
        products: event.products,
        returnUrl: event.returnUrl,
        cancelUrl: event.cancelUrl,
        buyerEmail: event.buyerEmail,
        buyerName: event.buyerName,
      );
      emit(
        state.copyWith(
          status: PaymentStatus.awaitingUser,
          checkoutUrl: link.url,
          reference: link.reference,
        ),
      );
    } on PaymentGatewayException catch (e) {
      emit(state.copyWith(status: PaymentStatus.failed, error: e));
    } catch (e) {
      emit(
        state.copyWith(
          status: PaymentStatus.failed,
          error: AppFailure(AppFailureCodes.paymentStartDetail, '$e'),
        ),
      );
    }
  }

  Future<void> _onVerify(
    OnVerifyPayOsPayment event,
    Emitter<PaymentState> emit,
  ) async {
    final reference = event.reference ?? state.reference;
    if (reference == null || reference.isEmpty) {
      emit(
        state.copyWith(
          status: PaymentStatus.failed,
          error: const AppFailure(AppFailureCodes.paymentVerify),
        ),
      );
      return;
    }
    emit(state.copyWith(status: PaymentStatus.pending, clearError: true));
    try {
      final result = await _gateway.queryStatus(reference);
      switch (result.status) {
        case PaymentStatus.paid:
          emit(
            state.copyWith(
              status: PaymentStatus.paid,
              transactionId: result.transactionId,
            ),
          );
        case PaymentStatus.cancelled:
          emit(
            state.copyWith(
              status: PaymentStatus.cancelled,
              error: const AppFailure(AppFailureCodes.paymentCancelled),
            ),
          );
        case PaymentStatus.pending:
        case PaymentStatus.awaitingUser:
          emit(state.copyWith(status: PaymentStatus.awaitingUser));
        case PaymentStatus.idle:
          emit(state.copyWith(status: PaymentStatus.awaitingUser));
        case PaymentStatus.failed:
          emit(
            state.copyWith(
              status: PaymentStatus.failed,
              error: const AppFailure(AppFailureCodes.paymentComplete),
            ),
          );
      }
    } on PaymentGatewayException catch (e) {
      emit(state.copyWith(status: PaymentStatus.failed, error: e));
    } catch (e) {
      emit(
        state.copyWith(
          status: PaymentStatus.failed,
          error: AppFailure(AppFailureCodes.paymentVerifyDetail, '$e'),
        ),
      );
    }
  }

  void _onReset(OnResetPaymentEvent event, Emitter<PaymentState> emit) {
    emit(const PaymentState());
  }
}
