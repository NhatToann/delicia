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

/// AddressFormScreen — create + edit form for a single address (UC-06).
///
/// Accepts an optional [existingAddress] via `state.extra`; when present
/// the screen prefills the controllers and submits an update event.
///
/// The inputs reuse the profile screen's pill shape (42 px, r15, "Yellow 2"
/// fill) so both profile screens read as one form language.
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
      backgroundColor: ColorsFrave.pageBg,
      body: Column(
        children: <Widget>[
          FigmaHeaderBand(
            title: isEditing
                ? context.l10n.addressEdit
                : context.l10n.addressAdd,
            onBack: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/client/home');
              }
            },
          ),
          Expanded(
            child: BlocConsumer<AddressBloc, AddressState>(
              listenWhen: (a, b) => a.error != b.error,
              listener: (_, state) {
                if (state.error != null) {
                  errorTextSnack(context, state.error!);
                }
              },
              builder: (_, state) {
                return LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 56,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _Field(
                              label: context.l10n.addressStreet,
                              controller: _street,
                              hintText: '1 Lê Lợi, Bến Nghé',
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                  ? context.l10n.addressStreetRequired
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            _Field(
                              label: context.l10n.addressReference,
                              controller: _reference,
                              hintText: 'Quận, tòa nhà, số phòng…',
                            ),
                            const SizedBox(height: 14),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Expanded(
                                  child: _Field(
                                    label: context.l10n.addressLatitude,
                                    controller: _latitude,
                                    hintText: '10.7717',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: _validateCoord,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _Field(
                                    label: context.l10n.addressLongitude,
                                    controller: _longitude,
                                    hintText: '106.7009',
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                          signed: true,
                                        ),
                                    validator: _validateCoord,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            _DefaultSwitch(
                              value: _isDefault,
                              onChanged: (v) =>
                                  setState(() => _isDefault = v),
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              height: 46,
                              child: FilledButton.icon(
                                onPressed: state.isMutating
                                    ? null
                                    : () => _submit(context),
                                style: FilledButton.styleFrom(
                                  backgroundColor: ColorsFrave.navOrange,
                                  foregroundColor: ColorsFrave.onOrange,
                                  disabledBackgroundColor:
                                      ColorsFrave.navOrange.withValues(
                                        alpha: 0.45,
                                      ),
                                  elevation: 0,
                                  shape: const StadiumBorder(),
                                ),
                                icon: state.isMutating
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: ColorsFrave.onOrange,
                                        ),
                                      )
                                    : const Icon(Icons.check, size: 18),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    state.isMutating
                                        ? context.l10n.addressSaving
                                        : isEditing
                                        ? context.l10n.addressSaveChanges
                                        : context.l10n.addressSave,
                                    style: FraveText.semiBold(
                                      14,
                                      color: ColorsFrave.onOrange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 46,
                              child: TextButton(
                                onPressed: () => context.pop(),
                                style: TextButton.styleFrom(
                                  foregroundColor: ColorsFrave.greyText,
                                  shape: const StadiumBorder(),
                                ),
                                child: Text(
                                  context.l10n.addressCancel,
                                  style: FraveText.semiBold(
                                    14,
                                    color: ColorsFrave.greyText,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.addressCoordinatesHint,
                              style: FraveText.regular(12, color: ColorsFrave.greyText),
                            ),
                          ],
                        ),
                      ),
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

  String? _validateCoord(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return context.l10n.addressCoordinateRequired;
    }
    final v = double.tryParse(raw.trim());
    if (v == null) return context.l10n.addressCoordinateInvalid;
    if (v < -180 || v > 180) return context.l10n.addressCoordinateRange;
    return null;
  }

  void _submit(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    final uid = context.read<AuthBloc>().state.user?.uid ?? '';
    if (uid.isEmpty) {
      errorTextSnack(context, context.l10n.profileSignInRequired);
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

/// The "use as default" toggle, styled with the kit's orange switch.
class _DefaultSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _DefaultSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: ColorsFrave.pillYellow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  context.l10n.addressUseAsDefault,
                  style: FraveText.medium(14, color: ColorsFrave.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.addressUseAsDefaultHint,
                  style: FraveText.regular(12, color: ColorsFrave.greyText),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: ColorsFrave.navOrange,
          ),
        ],
      ),
    );
  }
}

/// A labelled pill-shaped input — Figma: 42 px tall, r15, "Yellow 2" fill.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    this.keyboardType,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String hintText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 7),
          child: Text(
            label,
            style: FraveText.medium(14, color: ColorsFrave.ink),
          ),
        ),
        SizedBox(
          height: 42,
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: FraveText.regular(14, color: ColorsFrave.ink),
            decoration: InputDecoration(
              filled: true,
              fillColor: ColorsFrave.pillYellow,
              hintText: hintText,
              hintStyle: FraveText.regular(13, color: ColorsFrave.greyText),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: ColorsFrave.navOrange,
                  width: 1,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: ColorsFrave.errorColor,
                  width: 1,
                ),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: ColorsFrave.errorColor,
                  width: 1,
                ),
              ),
              errorStyle: FraveText.regular(11, color: ColorsFrave.errorColor),
            ),
          ),
        ),
      ],
    );
  }
}
