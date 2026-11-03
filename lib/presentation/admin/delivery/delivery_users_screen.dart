import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/delivery/delivery_bloc.dart';
import '../../../domain/models/delivery_user.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

/// AdminDeliveryUsersScreen — the delivery-driver management (UC-09).
///
/// The list shows every driver with an on / off switch. A disabled
/// driver keeps their history but is no longer offered when the admin
/// assigns an order.
class AdminDeliveryUsersScreen extends StatelessWidget {
  const AdminDeliveryUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeliveryBloc>(
      create: (context) => DeliveryBloc(
        deliveryUsersService: context.read<DeliveryUsersService>(),
      )..add(const DeliveryUsersLoadRequested()),
      child: const _AdminDeliveryUsersView(),
    );
  }
}

class _AdminDeliveryUsersView extends StatelessWidget {
  const _AdminDeliveryUsersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      appBar: AppBar(
        backgroundColor: ColorsFrave.navOrange,
        foregroundColor: ColorsFrave.onOrange,
        elevation: 0,
        leading: IconButton(
          onPressed: () => goBack(context, fallback: '/admin/home'),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          context.l10n.adminDeliveryTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/admin/delivery/new'),
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: context.l10n.adminDeliveryAdd,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          const _DeliverySearchField(),
          Expanded(
            child: BlocConsumer<DeliveryBloc, DeliveryState>(
              listenWhen: (previous, current) =>
                  previous.error != current.error && current.error != null ||
                  previous.deletedDriverName != current.deletedDriverName,
              listener: (context, state) {
                if (state.error != null) {
                  errorMessageSnack(context, state.error!);
                  return;
                }
                final deleted = state.deletedDriverName;
                if (deleted != null) {
                  successSnack(
                    context,
                    context.l10n.adminDeliveryDeleted(deleted),
                  );
                }
              },
              builder: (context, state) {
                if (state.isLoading && state.users.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  );
                }
                final users = state.visibleUsers;
                if (users.isEmpty) {
                  return const _DeliveryEmpty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: users.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _DeliveryUserTile(user: users[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// The search field above the driver list.
class _DeliverySearchField extends StatelessWidget {
  const _DeliverySearchField();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ColorsFrave.surfaceColor,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: TextField(
        onChanged: (value) =>
            context.read<DeliveryBloc>().add(DeliveryUserSearchChanged(value)),
        textInputAction: TextInputAction.search,
        style: FraveText.regular(14, color: ColorsFrave.ink),
        decoration: InputDecoration(
          hintText: context.l10n.adminDeliverySearchHint,
          hintStyle: FraveText.regular(14, color: ColorsFrave.greyText),
          prefixIcon: const Icon(
            Icons.search,
            size: 20,
            color: ColorsFrave.greyText,
          ),
          filled: true,
          fillColor: ColorsFrave.pageBg,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(RadiusFrave.field),
            borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1),
          ),
        ),
      ),
    );
  }
}

/// One driver row.
class _DeliveryUserTile extends StatelessWidget {
  const _DeliveryUserTile({required this.user});

  final DeliveryUser user;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 24,
            backgroundColor: user.isEnabled
                ? ColorsFrave.orangeSoft
                : ColorsFrave.surfaceVariant,
            child: Text(
              user.name.trim().isEmpty
                  ? '?'
                  : user.name.trim().characters.first.toUpperCase(),
              style: FraveText.medium(
                16,
                color: user.isEnabled
                    ? ColorsFrave.navOrange
                    : ColorsFrave.greyText,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: FraveText.medium(15, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 3),
                Text(
                  user.isEnabled
                      ? l10n.adminDeliveryEnabled
                      : l10n.adminDeliveryDisabled,
                  style: FraveText.light(12, color: user.isEnabled
                      ? ColorsFrave.successColor
                      : ColorsFrave.greyText),
                ),
                if (user.activeOrders > 0) ...<Widget>[
                  const SizedBox(height: 3),
                  Text(
                    l10n.adminDeliveryActiveOrders(user.activeOrders),
                    style: FraveText.light(12, color: ColorsFrave.greyText),
                  ),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: user.isEnabled,
            activeThumbColor: ColorsFrave.navOrange,
            onChanged: (value) {
              context.read<DeliveryBloc>().add(
                    DeliveryUserEnabledChanged(uid: user.uid, enabled: value),
                  );
            },
          ),
          IconButton(
            onPressed: () => _confirmDelete(context),
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: ColorsFrave.errorColor,
            ),
            tooltip: context.l10n.actionDelete,
          ),
        ],
      ),
    );
  }

  /// Asks for a confirmation and then removes the driver for good.
  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<DeliveryBloc>();

    // A driver that is still carrying orders must not vanish — the
    // orders would point at an account that does not exist any more.
    if (user.activeOrders > 0) {
      errorTextSnack(
        context,
        l10n.adminDeliveryDeleteBlocked(user.activeOrders),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        title: Text(
          l10n.adminDeliveryDeleteTitle,
          style: FraveText.semiBold(18, color: ColorsFrave.ink),
        ),
        content: Text(
          l10n.adminDeliveryDeleteMessage(user.name),
          style: FraveText.regular(14, color: ColorsFrave.greyText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.actionCancel,
              style: FraveText.medium(14, color: ColorsFrave.greyText),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.actionDelete,
              style: FraveText.medium(14, color: ColorsFrave.errorColor),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    bloc.add(
      DeliveryUserDeleted(
        uid: user.uid,
        email: user.email,
        name: user.name,
      ),
    );
  }
}

/// The empty state of the driver list.
class _DeliveryEmpty extends StatelessWidget {
  const _DeliveryEmpty();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 35),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.delivery_dining_outlined,
              size: 56,
              color: ColorsFrave.navOrange,
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.adminDeliveryEmpty,
              textAlign: TextAlign.center,
              style: FraveText.regular(15, color: ColorsFrave.greyText),
            ),
          ],
        ),
      ),
    );
  }
}
