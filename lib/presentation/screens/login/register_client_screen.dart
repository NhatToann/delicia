import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/auth_text_field.dart';
import '../../components/auth_widgets.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_loading.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';

/// Sign-up screen — matches `2 - C - Sign Up.png` from the UI kit.
///
/// Flow contract:
///   • Reached from `/intro` ("Create an account" pill) or `/login`
///     (Sign-Up link).
///   • Submitting a valid form → AuthBloc `RegisterEvent`. On success the
///     user is logged out and bounced back to /login (the sign-up screen
///     never holds the active session — see AuthBloc._onRegister).
///   • Tap "Already have an account?" → /login.
class RegisterClientScreen extends StatefulWidget {
  const RegisterClientScreen({super.key});

  @override
  State<RegisterClientScreen> createState() => _RegisterClientScreenState();
}

class _RegisterClientScreenState extends State<RegisterClientScreen> {
  final _keyForm = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_keyForm.currentState!.validate()) return;
    if (_password.text != _confirm.text) {
      errorTextSnack(context, context.l10n.validationPasswordsDoNotMatch);
      return;
    }
    FocusScope.of(context).unfocus();
    final parts = _fullName.text.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    context.read<AuthBloc>().add(
      RegisterEvent(
        email: _email.text.trim(),
        password: _password.text,
        firstName: first,
        lastName: last,
        phone: _phone.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is LoadingAuthState ||
          current is FailureAuthState ||
          current is RegisterSuccessState,
      listener: (context, state) {
        if (state is LoadingAuthState) {
          modalLoading(context);
        } else if (state is FailureAuthState) {
          Navigator.of(context, rootNavigator: true).pop();
          errorMessageSnack(context, state.error);
        } else if (state is RegisterSuccessState) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.authAccountCreated),
              backgroundColor: ColorsFrave.successColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
          context.go('/login');
        }
      },
      builder: (context, state) {
        final loading = state is LoadingAuthState;
        return Scaffold(
          backgroundColor: ColorsFrave.authBg,
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                AuthHeader(
                  title: context.l10n.actionSignUp,
                  onBack: () => goBack(context, fallback: '/intro'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: Form(
                      key: _keyForm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.authRegisterSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ColorsFrave.authInk,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.authRegisterTagline,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: ColorsFrave.authInkSoft,
                            ),
                          ),
                          const SizedBox(height: 28),

                          FieldCaption(context.l10n.authFullName),
                          AuthTextField(
                            controller: _fullName,
                            label: context.l10n.authFullName,
                            icon: Icons.person_outline_rounded,
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? context.l10n.validationNameRequired
                                    : null,
                          ),
                          const SizedBox(height: 16),

                          FieldCaption(context.l10n.authEmailAddress),
                          AuthTextField(
                            controller: _email,
                            label: context.l10n.authEmail,
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                          ),
                          const SizedBox(height: 16),

                          FieldCaption(context.l10n.authPhoneNumber),
                          AuthTextField(
                            controller: _phone,
                            label: context.l10n.authPhoneNumber,
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: _phoneValidator,
                          ),
                          const SizedBox(height: 16),

                          FieldCaption(context.l10n.authPassword),
                          AuthTextField(
                            controller: _password,
                            label: context.l10n.authPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: ColorsFrave.authInkSoft,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            validator: _passwordValidator,
                          ),
                          const SizedBox(height: 16),

                          FieldCaption(context.l10n.authConfirmPassword),
                          AuthTextField(
                            controller: _confirm,
                            label: context.l10n.authConfirmPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                size: 18,
                                color: ColorsFrave.authInkSoft,
                              ),
                              onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return context.l10n.validationConfirmPassword;
                              }
                              if (v != _password.text) {
                                return context.l10n.validationPasswordsDoNotMatch;
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 28),

                          AuthPrimaryButton(
                            label: context.l10n.actionSignUp,
                            icon: Icons.person_add_alt_1_rounded,
                            busy: loading,
                            onPressed: _submit,
                          ),

                          const SizedBox(height: 18),

                          Text(
                            context.l10n.authTermsAgreement,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11.5,
                              height: 1.5,
                              color: ColorsFrave.authInkSoft,
                            ),
                          ),
                          const SizedBox(height: 18),

                          AuthFooterLink(
                            prompt: context.l10n.authHasAccount,
                            actionLabel: context.l10n.actionSignIn,
                            onTap: () => context.go('/login'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String? _emailValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return context.l10n.validationEmailRequired;
    if (!v.contains('@') || !v.contains('.')) {
      return context.l10n.validationEmailInvalid;
    }
    return null;
  }

  String? _passwordValidator(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return context.l10n.validationPasswordRequired;
    if (v.length < 6) return context.l10n.validationPasswordTooShort;
    return null;
  }

  String? _phoneValidator(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return context.l10n.validationPhoneRequired;
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 12) {
      return context.l10n.validationPhoneInvalid;
    }
    return null;
  }
}
