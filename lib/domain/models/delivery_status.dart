/// State machine enum and transitions for Delivery flow (UC-11).
///
/// States flow:
///   pending -> accepted -> picked_up -> on_the_way -> delivered
/// (or cancelled from any non-terminal state).
enum DeliveryStatus {
  pending,
  preparing,
  accepted,
  pickedUp,
  onTheWay,
  delivered,
  cancelled;

  static const Map<DeliveryStatus, List<DeliveryStatus>> _validTransitions = {
    DeliveryStatus.pending: [
      DeliveryStatus.preparing,
      DeliveryStatus.accepted,
      DeliveryStatus.cancelled,
    ],
    DeliveryStatus.preparing: [
      DeliveryStatus.accepted,
      DeliveryStatus.cancelled,
    ],
    DeliveryStatus.accepted: [
      DeliveryStatus.pickedUp,
      DeliveryStatus.onTheWay,
      DeliveryStatus.delivered,
      DeliveryStatus.cancelled,
    ],
    DeliveryStatus.pickedUp: [
      DeliveryStatus.onTheWay,
      DeliveryStatus.delivered,
      DeliveryStatus.cancelled,
    ],
    DeliveryStatus.onTheWay: [
      DeliveryStatus.delivered,
      DeliveryStatus.cancelled,
    ],
    DeliveryStatus.delivered: [],
    DeliveryStatus.cancelled: [],
  };

  /// Returns true if transitioning from [this] state to [next] is allowed.
  bool canTransitionTo(DeliveryStatus next) {
    if (next == DeliveryStatus.delivered) {
      return this != DeliveryStatus.pending &&
          this != DeliveryStatus.preparing &&
          this != DeliveryStatus.cancelled &&
          this != DeliveryStatus.delivered;
    }
    final allowed = _validTransitions[this] ?? [];
    return allowed.contains(next);
  }

  /// Attempts to transition from [this] state to [next].
  /// Throws [StateError] if the transition is invalid.
  DeliveryStatus transitionTo(DeliveryStatus next) {
    if (!canTransitionTo(next)) {
      throw StateError(
        'Invalid state transition: Cannot transition from ${name} to ${next.name}.',
      );
    }
    return next;
  }

  /// The next sequential happy-path status (or null if delivered / cancelled).
  DeliveryStatus? get nextStep {
    switch (this) {
      case DeliveryStatus.pending:
        return DeliveryStatus.accepted;
      case DeliveryStatus.preparing:
        return DeliveryStatus.accepted;
      case DeliveryStatus.accepted:
        return DeliveryStatus.pickedUp;
      case DeliveryStatus.pickedUp:
        return DeliveryStatus.onTheWay;
      case DeliveryStatus.onTheWay:
        return DeliveryStatus.delivered;
      case DeliveryStatus.delivered:
      case DeliveryStatus.cancelled:
        return null;
    }
  }

  /// Human-friendly display label.
  String get label {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Pending';
      case DeliveryStatus.preparing:
        return 'Preparing';
      case DeliveryStatus.accepted:
        return 'Accepted';
      case DeliveryStatus.pickedUp:
        return 'Picked Up';
      case DeliveryStatus.onTheWay:
        return 'On The Way';
      case DeliveryStatus.delivered:
        return 'Delivered';
      case DeliveryStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Human-friendly display label in Vietnamese.
  String get labelVi {
    switch (this) {
      case DeliveryStatus.pending:
        return 'Chờ nhận đơn';
      case DeliveryStatus.preparing:
        return 'Đang chuẩn bị';
      case DeliveryStatus.accepted:
        return 'Đã nhận đơn';
      case DeliveryStatus.pickedUp:
        return 'Đã lấy hàng';
      case DeliveryStatus.onTheWay:
        return 'Đang giao hàng';
      case DeliveryStatus.delivered:
        return 'Đã giao hàng';
      case DeliveryStatus.cancelled:
        return 'Đã hủy';
    }
  }

  /// Database status string mapping.
  String get dbStatus {
    switch (this) {
      case DeliveryStatus.pending:
        return 'PAID OUT';
      case DeliveryStatus.preparing:
        return 'PREPARING';
      case DeliveryStatus.accepted:
        return 'DISPATCHED';
      case DeliveryStatus.pickedUp:
        return 'PICKED UP';
      case DeliveryStatus.onTheWay:
        return 'ON WAY';
      case DeliveryStatus.delivered:
        return 'DELIVERED';
      case DeliveryStatus.cancelled:
        return 'CANCELLED';
    }
  }

  /// Parses a status string (from database or API) into [DeliveryStatus].
  static DeliveryStatus fromString(String raw) {
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'PENDING':
      case 'PAID_OUT':
        return DeliveryStatus.pending;
      case 'PREPARING':
        return DeliveryStatus.preparing;
      case 'ACCEPTED':
      case 'DISPATCHED':
        return DeliveryStatus.accepted;
      case 'PICKED_UP':
        return DeliveryStatus.pickedUp;
      case 'ON_THE_WAY':
      case 'ON_WAY':
        return DeliveryStatus.onTheWay;
      case 'DELIVERED':
        return DeliveryStatus.delivered;
      case 'CANCELLED':
      case 'REJECTED':
        return DeliveryStatus.cancelled;
      default:
        return DeliveryStatus.pending;
    }
  }
}
