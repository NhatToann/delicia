import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:flutter/foundation.dart';

import '../../models/delivery_user.dart';
import '../../services/admin_orders_service.dart';
import '../../services/app_failure.dart';

part 'delivery_event.dart';
part 'delivery_state.dart';

/// DeliveryBloc — the admin's delivery-driver management (UC-09).
///
/// The driver list is a realtime stream of every account with the
/// delivery role. The admin can enable or disable a driver; a disabled
/// driver keeps their history but is no longer offered when assigning
/// an order.
class DeliveryBloc extends Bloc<DeliveryEvent, DeliveryState> {
  DeliveryBloc({required DeliveryUsersService deliveryUsersService})
      : _deliveryUsersService = deliveryUsersService,
        super(const DeliveryState()) {
    on<DeliveryUsersLoadRequested>(_onLoadRequested);
    on<DeliveryUserSearchChanged>(_onSearchChanged);
    on<DeliveryUserEnabledChanged>(_onEnabledChanged);
    on<DeliveryUserCreated>(_onCreated);
    on<DeliveryUserDeleted>(_onDeleted);
    on<_DeliveryUsersUpdated>(_onUsersUpdated);
    on<_DeliveryUsersFailed>(_onUsersFailed);
  }

  final DeliveryUsersService _deliveryUsersService;

  StreamSubscription<List<DeliveryUser>>? _usersSub;

  Future<void> _onLoadRequested(
    DeliveryUsersLoadRequested event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, clearError: true));

    await _usersSub?.cancel();
    _usersSub = null;

    _usersSub = _deliveryUsersService.watchDeliveryUsers().listen(
      (users) {
        if (isClosed) return;
        add(_DeliveryUsersUpdated(users));
      },
      onError: (Object e) {
        if (isClosed) return;
        add(_DeliveryUsersFailed(e));
      },
    );
  }

  void _onSearchChanged(
    DeliveryUserSearchChanged event,
    Emitter<DeliveryState> emit,
  ) {
    emit(
      state.copyWith(
        query: event.query,
        visibleUsers: _filter(state.users, event.query),
      ),
    );
  }

  Future<void> _onEnabledChanged(
    DeliveryUserEnabledChanged event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      await _deliveryUsersService.setDeliveryEnabled(
        uid: event.uid,
        enabled: event.enabled,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          actionSucceeded: true,
          clearActionSucceeded: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  void _onUsersUpdated(
    _DeliveryUsersUpdated event,
    Emitter<DeliveryState> emit,
  ) {
    emit(
      state.copyWith(
        isLoading: false,
        clearError: true,
        users: event.users,
        visibleUsers: _filter(event.users, state.query),
      ),
    );
  }
  void _onUsersFailed(
    _DeliveryUsersFailed event,
    Emitter<DeliveryState> emit,
  ) {
    emit(state.copyWith(isLoading: false, error: asFailure(event.error)));
  }

  /// Creates a driver account.
  ///
  /// The list itself is refreshed by the realtime feed — the new profile
  /// shows up on its own — so the bloc only reports the outcome.
  Future<void> _onCreated(
    DeliveryUserCreated event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearDriverCreated: true,
        clearDeletedDriverName: true,
      ),
    );
    try {
      await _deliveryUsersService.createDeliveryDriver(
        email: event.email,
        password: event.password,
        firstName: event.firstName,
        lastName: event.lastName,
        phone: event.phone,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          driverCreated: true,
          clearDriverCreated: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Deletes a driver account.
  Future<void> _onDeleted(
    DeliveryUserDeleted event,
    Emitter<DeliveryState> emit,
  ) async {
    emit(
      state.copyWith(
        isSubmitting: true,
        clearError: true,
        clearDriverCreated: true,
        clearDeletedDriverName: true,
      ),
    );
    try {
      await _deliveryUsersService.deleteDeliveryDriver(
        uid: event.uid,
        email: event.email,
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          deletedDriverName: event.name,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, error: asFailure(e)));
    }
  }

  /// Case-insensitive name / phone / email filter.
  static List<DeliveryUser> _filter(
    List<DeliveryUser> source,
    String query,
  ) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return List<DeliveryUser>.unmodifiable(source);
    return source
        .where(
          (u) =>
              u.name.toLowerCase().contains(needle) ||
              u.phone.toLowerCase().contains(needle) ||
              u.email.toLowerCase().contains(needle),
        )
        .toList(growable: false);
  }

  @override
  Future<void> close() async {
    await _usersSub?.cancel();
    _usersSub = null;
    return super.close();
  }
}
