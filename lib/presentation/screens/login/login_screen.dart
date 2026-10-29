import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/auth_text_field.dart';
import '../../components/auth_widgets.dart';
import '../../helpers/error_message.dart';
import '../../helpers/l10n_extension.dart';
import '../../helpers/modal_loading.dart';
import '../../helpers/navigation_helper.dart';
import '../../themes/colors_frave.dart';

/// Login screen — matches `2 - A - Log In.png` from the UI kit.
///
/// Flow contract:
///   • Reached from `/intro` ("Sign in" pill).
///   • Submitting valid email/password → AuthBloc `LoginEvent` →
///       role 1|3 → /select-role
///       role 2   → /client/home
///       default  → /intro
///   • Tap "Sign Up" footer → /register.
///   • Tap back → /intro.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _keyForm = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_keyForm.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    context.read<AuthBloc>().add(LoginEvent(_email.text, _password.text));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (previous, current) {
        // Only react when the bloc leaves Loading/Failure — LoginScreen
        // pops the loading modal itself on success/failure; other states
        // belong to the launch flow, not to this screen.
        if (current is LoadingAuthState || current is FailureAuthState) {
          return true;
        }
        return current.runtimeType.toString() == 'AuthState' &&
            current.rolId.isNotEmpty;
      },
      listener: (context, state) {
        if (state is LoadingAuthState) {
          modalLoading(context);
        } else if (state is FailureAuthState) {
          Navigator.of(context, rootNavigator: true).pop();
          errorMessageSnack(context, state.error);
        } else if (state.runtimeType.toString() == 'AuthState' && state.rolId.isNotEmpty) {
          // Pop the loading modal first, then route to the role destination.
          Navigator.of(context, rootNavigator: true).pop();
          switch (state.rolId) {
            case '1':
            case '3':
              context.go('/select-role');
              break;
            case '2':
              context.go('/client/home');
              break;
            default:
              context.go('/intro');
          }
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
                  title: context.l10n.actionSignIn,
                  onBack: () => goBack(context, fallback: '/intro'),
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
                          SizedBox(
                            height: 132,
                            child: SvgPicture.asset(
                              'assets/logos/delicia-courier.svg',
                              fit: BoxFit.contain,
                              colorFilter: const ColorFilter.mode(
                                ColorsFrave.welcomeAccent,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Text(
                            context.l10n.authLoginSubtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: ColorsFrave.authInk,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 28),

                          FieldCaption(context.l10n.authEmailAddress),
                          AuthTextField(
                            controller: _email,
                            label: context.l10n.authEmail,
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: _emailValidator,
                          ),

                          const SizedBox(height: 18),

                          FieldCaption(context.l10n.authPassword),
                          AuthTextField(
                            controller: _password,
                            label: context.l10n.authPassword,
                            icon: Icons.lock_outline_rounded,
                            obscure: true,
                            validator: _passwordValidator,
                            onSubmitted: (_) => _submit(),
                          ),

                          const SizedBox(height: 12),

                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => context.push('/forgot-password'),
                              style: TextButton.styleFrom(
                                foregroundColor: ColorsFrave.authAccent,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                context.l10n.authForgotPassword,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          AuthPrimaryButton(
                            label: context.l10n.actionSignIn,
                            icon: Icons.login_rounded,
                            busy: loading,
                            onPressed: _submit,
                          ),

                          const SizedBox(height: 32),

                          AuthDivider(label: context.l10n.authOrContinueWith),

                          const SizedBox(height: 20),

                          const AuthSocialRow(
                            onFacebook: _noOp,
                            onGoogle: _noOp,
                            onApple: _noOp,
                          ),

                          const SizedBox(height: 36),

                          AuthFooterLink(
                            prompt: context.l10n.authNoAccount,
                            actionLabel: context.l10n.actionSignUp,
                            onTap: () => context.push('/register'),
                          ),

                          const SizedBox(height: 24),
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

  // --- social + validator helpers ----------------------------------------
  static void _noOp() {}

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
}
