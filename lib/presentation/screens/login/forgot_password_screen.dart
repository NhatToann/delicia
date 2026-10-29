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

/// ForgotPasswordScreen — matches `2 - B - Log In.png` (variant B).
///
/// Flow contract:
///   • Reached from `/login` ("Forgot Password?" link).
///   • Submitting a valid email → AuthBloc `ForgotPasswordEvent` →
///       success → /check-email
///       failure → snackbar
///   • Tap back → /login.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _keyForm = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_keyForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(ForgotPasswordEvent(_email.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is LoadingAuthState ||
          current is FailureAuthState ||
          current is ForgotPasswordSuccessState,
      listener: (context, state) {
        if (state is LoadingAuthState) {
          modalLoading(context);
        } else if (state is FailureAuthState) {
          Navigator.of(context, rootNavigator: true).pop();
          errorMessageSnack(context, state.error);
        } else if (state is ForgotPasswordSuccessState) {
          Navigator.of(context, rootNavigator: true).pop();
          context.go('/check-email');
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
                  title: context.l10n.authForgotPasswordTitle,
                  onBack: () => goBack(context, fallback: '/login'),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                    child: Form(
                      key: _keyForm,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.authResetPasswordSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ColorsFrave.authInk,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.authResetPasswordDescription,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                              fontWeight: FontWeight.w400,
                              color: ColorsFrave.authInkSoft,
                            ),
                          ),
                          const SizedBox(height: 32),
                          FieldCaption(context.l10n.authEmailAddress),
                          AuthTextField(
                            controller: _email,
                            label: context.l10n.authEmail,
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                            onSubmitted: (_) => _submit(),
                          ),
                          const SizedBox(height: 28),
                          AuthPrimaryButton(
                            label: context.l10n.actionSend,
                            icon: Icons.send_rounded,
                            busy: loading,
                            onPressed: _submit,
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
}
