import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/bloc/delivery/delivery_bloc.dart';
import '../../../domain/services/admin_orders_service.dart';
import '../../components/btn_frave.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';
import '../../themes/type_frave.dart';

/// AdminDriverFormScreen — creates a new delivery driver (UC-09).
///
/// The screen is opened from the driver list. It asks for the name, the
/// phone number, the email and the password of the new account; the
/// backend creates the Firebase Auth account **and** the `users/{uid}`
/// profile that carries `rolId == 3`.
///
/// The screen owns its own [DeliveryBloc] so it does not fight with the
/// list screen for the same state.
class AdminDriverFormScreen extends StatelessWidget {
  const AdminDriverFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DeliveryBloc>(
      create: (context) => DeliveryBloc(
        deliveryUsersService: context.read<DeliveryUsersService>(),
      ),
      child: const _AdminDriverFormView(),
    );
  }
}

class _AdminDriverFormView extends StatefulWidget {
  const _AdminDriverFormView();

  @override
  State<_AdminDriverFormView> createState() => _AdminDriverFormViewState();
}

class _AdminDriverFormViewState extends State<_AdminDriverFormView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: ColorsFrave.pageBg,
      appBar: AppBar(
        backgroundColor: ColorsFrave.navOrange,
        foregroundColor: ColorsFrave.onOrange,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
        ),
        title: Text(
          l10n.adminDeliveryAddTitle,
          style: FraveText.semiBold(20, color: ColorsFrave.onOrange),
        ),
      ),
      body: BlocListener<DeliveryBloc, DeliveryState>(
        listenWhen: (previous, current) =>
            previous.driverCreated != current.driverCreated ||
            previous.error != current.error,
        listener: (context, state) {
          if (state.error != null) {
            errorMessageSnack(context, state.error!);
            return;
          }
          if (state.driverCreated) {
            successSnack(context, l10n.adminDeliveryAdded(_name.text.trim()));
            Navigator.of(context).pop(true);
          }
        },
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: <Widget>[
              _Field(
                label: l10n.adminDeliveryName,
                controller: _name,
                textInputAction: TextInputAction.next,
                validator: (value) => (value ?? '').trim().isEmpty
                    ? l10n.adminDeliveryNameRequired
                    : null,
              ),
              const SizedBox(height: 14),
              _Field(
                label: l10n.adminDeliveryPhone,
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                validator: _validatePhone,
              ),
              const SizedBox(height: 14),
              _Field(
                label: l10n.adminDeliveryEmail,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: _validateEmail,
              ),
              const SizedBox(height: 14),
              _Field(
                label: l10n.adminDeliveryPassword,
                controller: _password,
                obscure: true,
                textInputAction: TextInputAction.done,
                validator: _validatePassword,
              ),
              const SizedBox(height: 28),
              BtnFrave(
                text: l10n.adminDeliveryAdd,
                icon: Icons.person_add_alt_1_rounded,
                isLoading: context.select<DeliveryBloc, bool>(
                  (bloc) => bloc.state.isSubmitting,
                ),
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final fullName = _name.text.trim();
    final parts = fullName.split(RegExp(r'\s+'));
    final firstName = parts.first;
    final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    context.read<DeliveryBloc>().add(
          DeliveryUserCreated(
            email: _email.text.trim(),
            password: _password.text,
            firstName: firstName,
            lastName: lastName,
            phone: _phone.text.trim(),
          ),
        );
  }

  String? _validatePhone(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return context.l10n.adminDeliveryPhoneRequired;
    final digits = raw.replaceAll(RegExp(r'[\s().-]'), '');
    if (!RegExp(r'^0\d{8,10}$').hasMatch(digits) &&
        !RegExp(r'^\+?[1-9]\d{7,14}$').hasMatch(digits)) {
      return context.l10n.adminDeliveryPhoneInvalid;
    }
    return null;
  }

  String? _validateEmail(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return context.l10n.adminDeliveryEmailRequired;
    if (!RegExp(
      r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
      caseSensitive: false,
    ).hasMatch(raw)) {
      return context.l10n.adminDeliveryEmailInvalid;
    }
    return null;
  }

  String? _validatePassword(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) return context.l10n.adminDeliveryPasswordRequired;
    if (raw.length < 6) return context.l10n.adminDeliveryPasswordTooShort;
    return null;
  }
}

/// A labelled text field of the admin driver form.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.obscure = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: FraveText.medium(14, color: ColorsFrave.ink),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          validator: validator,
          style: FraveText.regular(14, color: ColorsFrave.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: ColorsFrave.surfaceColor,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.outlineVariant),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(RadiusFrave.field),
              borderSide: const BorderSide(color: ColorsFrave.navOrange, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
