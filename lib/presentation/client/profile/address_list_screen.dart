import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/models/client_address.dart';
import '../../components/btn_frave.dart';
import '../../components/shimmer_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// AddressListScreen — listing + CRUD entry points for the client's saved
/// addresses (UC-06).
class AddressListScreen extends StatefulWidget {
  const AddressListScreen({super.key});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  String? _loadedUid;

  @override
  void initState() {
    super.initState();
    // No fetch here — the build() method reacts to AuthBloc state changes
    // and kicks off the load once the user is available.
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: const TextCustom('My Addresses', fontWeight: FontWeight.bold),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: ColorsFrave.primaryColor),
            onPressed: uid.isEmpty
                ? null
                : () => context.push('/client/profile/addresses/new'),
          ),
        ],
      ),
      body: BlocConsumer<AddressBloc, AddressState>(
        listenWhen: (a, b) => a.error != b.error,
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          }
        },
        builder: (ctx, state) {
          if (state.isLoading && state.addresses.isEmpty) {
            return const _LoadingShell();
          }
          return RefreshIndicator(
            color: ColorsFrave.primaryColor,
            onRefresh: () async {
              if (uid.isEmpty) return;
              context.read<AddressBloc>().add(OnLoadAddressesEvent(uid: uid));
              await Future<void>.delayed(const Duration(milliseconds: 600));
            },
            child: state.addresses.isEmpty
                ? const _EmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.all(20),
                    itemCount: state.addresses.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (_, i) =>
                        _AddressCard(address: state.addresses[i]),
                  ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: ColorsFrave.primaryColor,
        foregroundColor: Colors.white,
        onPressed: uid.isEmpty
            ? null
            : () => context.push('/client/profile/addresses/new'),
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add address'),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final ClientAddress address;
  const _AddressCard({required this.address});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: ColorsFrave.primaryColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextCustom(address.street, fontWeight: FontWeight.bold),
              ),
              if (address.isDefault == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ColorsFrave.secondaryColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const TextCustom(
                    'Default',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          if (address.reference.isNotEmpty) ...[
            const SizedBox(height: 4),
            TextCustom(
              address.reference,
              color: ColorsFrave.greyText,
              fontSize: 13,
            ),
          ],
          const SizedBox(height: 8),
          TextCustom(
            'Lat ${address.latitude.toStringAsFixed(4)}, '
            'Lng ${address.longitude.toStringAsFixed(4)}',
            color: ColorsFrave.greyText,
            fontSize: 12,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (address.isDefault != true)
                TextButton.icon(
                  onPressed: () => context.read<AddressBloc>().add(
                    OnSetDefaultAddressEvent(uid: uid, addressId: address.id),
                  ),
                  icon: const Icon(
                    Icons.star_outline,
                    size: 18,
                    color: ColorsFrave.secondaryColor,
                  ),
                  label: const TextCustom(
                    'Set default',
                    color: ColorsFrave.secondaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              TextButton.icon(
                onPressed: () => context.push(
                  '/client/profile/addresses/edit/${address.id}',
                  extra: address,
                ),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: ColorsFrave.primaryColor,
                ),
                label: const TextCustom(
                  'Edit',
                  color: ColorsFrave.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextButton.icon(
                onPressed: () => _confirmDelete(context, uid, address),
                icon: const Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: ColorsFrave.errorColor,
                ),
                label: const TextCustom(
                  'Delete',
                  color: ColorsFrave.errorColor,
                  fontWeight: FontWeight.w600,
                ),
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
      builder: (_) => AlertDialog(
        title: const TextCustom('Delete address?', fontWeight: FontWeight.bold),
        content: TextCustom(
          '${address.street} will be removed.',
          color: ColorsFrave.greyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const TextCustom('Cancel', color: ColorsFrave.greyText),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ColorsFrave.errorColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<AddressBloc>().add(
        OnDeleteAddressEvent(uid: uid, addressId: address.id),
      );
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Icon(
          Icons.location_off_outlined,
          size: 96,
          color: ColorsFrave.greyText,
        ),
        const SizedBox(height: 12),
        const TextCustom(
          'No saved addresses yet',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const TextCustom(
          'Add your first delivery address to speed up checkout.',
          color: ColorsFrave.greyText,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 18),
        BtnFrave(
          text: 'Add address',
          onPressed: () => context.push('/client/profile/addresses/new'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _LoadingShell extends StatelessWidget {
  const _LoadingShell();

  @override
  Widget build(BuildContext context) {
    return ShimmerFrave(
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: 3,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 110,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
