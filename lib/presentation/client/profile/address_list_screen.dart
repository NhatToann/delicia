import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/models/client_address.dart';
import '../../components/figma_header_band.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  String? _loadedUid;

  void _showSuccessSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: FraveText.medium(14, color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthBloc>().state.user?.uid ?? '';
    if (uid.isNotEmpty && _loadedUid != uid) {
      _loadedUid = uid;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<AddressBloc>().add(OnLoadAddressesEvent(uid: uid));
        context.read<AddressBloc>().add(OnWatchAddressesEvent(uid: uid));
      });
    }
    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      body: Column(
        children: <Widget>[
          FigmaHeaderBand(
            title: context.l10n.addressListTitle,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client/home');
              }
            },
            actions: <Widget>[
              IconButton(
                tooltip: context.l10n.addressAdd,
                icon: const Icon(Icons.add, color: ColorsFrave.ink),
                onPressed: uid.isEmpty
                    ? null
                    : () => context.push('/client/profile/addresses/new'),
              ),
            ],
          ),
          Expanded(
            child: BlocConsumer<AddressBloc, AddressState>(
              listener: (_, state) {
                if (state.error != null) {
                  errorTextSnack(context, state.error!);
                }
              },
              builder: (ctx, state) {
                if (state.isLoading && state.addresses.isEmpty) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: ColorsFrave.navOrange,
                    ),
                  );
                }
                return RefreshIndicator(
                  color: ColorsFrave.navOrange,
                  onRefresh: () async {
                    if (uid.isEmpty) return;
                    context.read<AddressBloc>().add(
                      OnLoadAddressesEvent(uid: uid),
                    );
                    await Future<void>.delayed(
                      const Duration(milliseconds: 600),
                    );
                  },
                  child: state.addresses.isEmpty
                      ? _EmptyState()
                      : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    itemCount: state.addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (_, i) => _AddressCard(
                      address: state.addresses[i],
                      onSuccessAction: (msg) => _showSuccessSnack(context, msg),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final ClientAddress address;
  final ValueChanged<String> onSuccessAction;

  const _AddressCard({required this.address, required this.onSuccessAction});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    final isDefault = address.isDefault == true;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ColorsFrave.surfaceColor,
        borderRadius: BorderRadius.circular(RadiusFrave.card),
        border: isDefault
            ? Border.all(color: ColorsFrave.navOrange.withValues(alpha: 0.5), width: 1.5)
            : null,
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isDefault ? ColorsFrave.navOrange : ColorsFrave.orangeSoft,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.location_on_outlined,
                  color: isDefault ? ColorsFrave.onOrange : ColorsFrave.navOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            address.street,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: FraveText.semiBold(15, color: ColorsFrave.ink),
                          ),
                        ),
                        if (isDefault) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: ColorsFrave.pillYellow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              context.l10n.addressDefault,
                              style: FraveText.medium(11, color: ColorsFrave.ink),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (address.reference.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        address.reference,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: FraveText.regular(13, color: ColorsFrave.greyText),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, thickness: 1, color: ColorsFrave.dividerOrange),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (!isDefault)
                _Action(
                  icon: Icons.star_outline,
                  label: context.l10n.addressSetDefault,
                  color: ColorsFrave.navOrange,
                  onTap: () {
                    context.read<AddressBloc>().add(
                      OnSetDefaultAddressEvent(uid: uid, addressId: address.id),
                    );
                    onSuccessAction('Đã đặt làm địa chỉ mặc định thành công!');
                  },
                )
              else
                const SizedBox.shrink(),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Action(
                    icon: Icons.edit_outlined,
                    label: context.l10n.actionEdit,
                    color: ColorsFrave.navOrange,
                    onTap: () => context.push(
                      '/client/profile/addresses/edit/${address.id}',
                      extra: address,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Action(
                    icon: Icons.delete_outline,
                    label: context.l10n.addressDelete,
                    color: ColorsFrave.errorColor,
                    onTap: () => _confirmDelete(context, uid, address),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context,
      String uid,
      ClientAddress address,
      ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: ColorsFrave.surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RadiusFrave.sheet),
        ),
        title: Text(
          context.l10n.addressDeleteTitle,
          style: FraveText.bold(18, color: ColorsFrave.ink),
        ),
        content: Text(
          context.l10n.addressDeleteBody(address.street),
          style: FraveText.regular(14, color: ColorsFrave.greyText),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.addressCancel,
              style: FraveText.medium(14, color: ColorsFrave.greyText),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: ColorsFrave.onOrange,
              shape: const StadiumBorder(),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              context.l10n.addressDelete,
              style: FraveText.medium(14, color: ColorsFrave.onOrange),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AddressBloc>().add(
        OnDeleteAddressEvent(uid: uid, addressId: address.id),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Đã xóa địa chỉ thành công!'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(label, style: FraveText.medium(13, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 60),
      children: <Widget>[
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: const BoxDecoration(
              color: ColorsFrave.orangeSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.location_off_outlined,
              size: 48,
              color: ColorsFrave.navOrange,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          context.l10n.addressEmptyTitle,
          textAlign: TextAlign.center,
          style: FraveText.bold(18, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.addressEmptyBody,
          textAlign: TextAlign.center,
          style: FraveText.regular(13, color: ColorsFrave.greyText),
        ),
        const SizedBox(height: 28),
        SizedBox(
          height: 46,
          child: FilledButton.icon(
            onPressed: () => context.push('/client/profile/addresses/new'),
            style: FilledButton.styleFrom(
              backgroundColor: ColorsFrave.navOrange,
              foregroundColor: ColorsFrave.onOrange,
              elevation: 0,
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text(
              context.l10n.addressAdd,
              style: FraveText.semiBold(14, color: ColorsFrave.onOrange),
            ),
          ),
        ),
      ],
    );
  }
}