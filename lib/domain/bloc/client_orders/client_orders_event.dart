part of 'client_orders_bloc.dart';

@immutable
abstract class ClientOrdersEvent {
  const ClientOrdersEvent();
}

/// One-shot load — `OnSubscribeClientOrdersEvent` keeps the list live.
class OnLoadClientOrdersEvent extends ClientOrdersEvent {
  final String clientId;
  const OnLoadClientOrdersEvent({required this.clientId});
}

class OnRefreshClientOrdersEvent extends ClientOrdersEvent {
  final String clientId;
  const OnRefreshClientOrdersEvent({required this.clientId});
}

/// Starts the realtime subscription. Safe to call repeatedly; the BLoC
/// cancels the previous subscription before attaching a new one.
class OnSubscribeClientOrdersEvent extends ClientOrdersEvent {
  final String clientId;
  const OnSubscribeClientOrdersEvent({required this.clientId});
}

class OnCancelOrderEvent extends ClientOrdersEvent {
  final String clientId;
  final String orderId;
  final String reason;
  const OnCancelOrderEvent({
    required this.clientId,
    required this.orderId,
    this.reason = 'Cancelled by client',
  });
}

class OnClearClientOrdersErrorEvent extends ClientOrdersEvent {
  const OnClearClientOrdersErrorEvent();
}
