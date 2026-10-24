import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/address/address_bloc.dart';
import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../domain/models/client_address.dart';
import '../../components/btn_frave.dart';
import '../../components/form_field_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../themes/colors_frave.dart';

/// AddressFormScreen — create + edit form for a single address (UC-06).
///
/// Accepts an optional [existingAddress] via `state.extra`; when present
/// the screen prefills the controllers and submits an update event.
class AddressFormScreen extends StatefulWidget {
  final ClientAddress? existingAddress;
  const AddressFormScreen({super.key, this.existingAddress});

  @override
  State<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends State<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _street;
  late final TextEditingController _reference;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  late bool _isDefault;
  late String _editingId;

  @override
  void initState() {
    super.initState();
    final a = widget.existingAddress;
    _street = TextEditingController(text: a?.street ?? '');
    _reference = TextEditingController(text: a?.reference ?? '');
    _latitude = TextEditingController(
      text: a != null ? a.latitude.toString() : '',
    );
    _longitude = TextEditingController(
      text: a != null ? a.longitude.toString() : '',
    );
    _isDefault = a?.isDefault ?? false;
    _editingId = a?.id ?? '';
  }

  @override
  void dispose() {
    _street.dispose();
    _reference.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingAddress != null;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: ColorsFrave.darkText),
          onPressed: () => context.pop(),
        ),
        title: TextCustom(
          isEditing ? 'Edit address' : 'Add address',
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<AddressBloc, AddressState>(
        listenWhen: (a, b) => a.error != b.error,
        listener: (_, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
          }
        },
        builder: (_, state) {
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LabelText('Street'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller: _street,
                      hintText: 'e.g. 1 Lê Lợi, Bến Nghé',
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Street is required'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    const _LabelText('Reference (optional)'),
                    const SizedBox(height: 6),
                    FormFieldFrave(
                      controller: _reference,
                      hintText: 'District, city, building, …',
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _LabelText('Latitude'),
                              const SizedBox(height: 6),
                              FormFieldFrave(
                                controller: _latitude,
                                hintText: '10.7717',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                validator: _validateCoord,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _LabelText('Longitude'),
                              const SizedBox(height: 6),
                              FormFieldFrave(
                                controller: _longitude,
                                hintText: '106.7009',
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                      signed: true,
                                    ),
                                validator: _validateCoord,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                      title: const TextCustom(
                        'Use as default address',
                        fontWeight: FontWeight.w600,
                      ),
                      subtitle: const TextCustom(
                        'Replaces the previously selected default.',
                        color: ColorsFrave.greyText,
                        fontSize: 12,
                      ),
                      activeThumbColor: ColorsFrave.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              BtnFrave(
                text: state.isMutating
                    ? 'Saving…'
                    : (isEditing ? 'Save changes' : 'Add address'),
                onPressed: state.isMutating ? null : () => _submit(context),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: ColorsFrave.greyText),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const TextCustom('Cancel', color: ColorsFrave.greyText),
              ),
              const SizedBox(height: 12),
              TextCustom(
                'Don\'t know the coordinates? Use your map app to pick '
                'a spot and copy the latitude/longitude here.',
                color: ColorsFrave.greyText,
                fontSize: 12,
              ),
            ],
          );
        },
      ),
    );
  }

  String? _validateCoord(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'Required';
    }
    final v = double.tryParse(raw.trim());
    if (v == null) return 'Enter a number';
    if (v < -180 || v > 180) return 'Out of range';
    return null;
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    if (uid.isEmpty) {
      errorMessageSnack(context, 'Sign in to save an address.');
      return;
    }
    final lat = double.parse(_latitude.text.trim());
    final lng = double.parse(_longitude.text.trim());
    final bloc = context.read<AddressBloc>();
    if (_editingId.isEmpty) {
      bloc.add(
        OnAddAddressEvent(
          uid: uid,
          address: ClientAddress(
            id: '',
            street: _street.text.trim(),
            reference: _reference.text.trim(),
            latitude: lat,
            longitude: lng,
            isDefault: _isDefault,
          ),
        ),
      );
    } else {
      bloc.add(
        OnUpdateAddressEvent(
          uid: uid,
          address: ClientAddress(
            id: _editingId,
            street: _street.text.trim(),
            reference: _reference.text.trim(),
            latitude: lat,
            longitude: lng,
            isDefault: _isDefault,
          ),
        ),
      );
    }
    // Bounce after letting the snack/toast show first.
    Future<void>.delayed(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (!context.mounted) return;
      context.pop();
    });
  }
}

class _LabelText extends StatelessWidget {
  final String text;
  const _LabelText(this.text);

  @override
  Widget build(BuildContext context) {
    return TextCustom(text, fontWeight: FontWeight.w600);
  }
}
