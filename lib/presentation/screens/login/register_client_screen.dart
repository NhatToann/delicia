import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/btn_frave.dart';
import '../../components/form_field_frave.dart';
import '../../components/text_custom.dart';
import '../../helpers/error_message.dart';
import '../../helpers/modal_loading.dart';
import '../../themes/colors_frave.dart';

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
      errorMessageSnack(context, 'Passwords do not match');
      return;
    }
    // Split "John Doe" -> firstName="John", lastName="Doe" (rest of words
    // collapse into lastName so "Mary Ann Smith" works too).
    final parts = _fullName.text.trim().split(RegExp(r'\s+'));
    final first = parts.isEmpty ? '' : parts.first;
    final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    context.read<AuthBloc>().add(RegisterEvent(
          email: _email.text.trim(),
          password: _password.text,
          firstName: first,
          lastName: last,
          phone: _phone.text.trim(),
        ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LoadingAuthState) {
          modalLoading(context);
        } else if (state is FailureAuthState) {
          Navigator.of(context, rootNavigator: true).pop();
          errorMessageSnack(context, state.error);
        } else if (state is RegisterSuccessState) {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Please sign in.'),
              backgroundColor: Color(0xFF22A45D),
            ),
          );
          context.go('/login');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Form(
            key: _keyForm,
            child: ListView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_outlined),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 8),
                const TextCustom(
                  'Create account',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                const TextCustom(
                  'Sign up to start ordering',
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 24),
                const TextCustom('Full name'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _fullName,
                  hintText: 'John Doe',
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),
                const TextCustom('Email'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _email,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: validatedEmail,
                ),
                const SizedBox(height: 16),
                const TextCustom('Phone'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _phone,
                  hintText: '+84xxxxxxxxx',
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Phone is required';
                    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
                    if (digits.length < 9 || digits.length > 12) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                const TextCustom('Password'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _password,
                  hintText: '********',
                  isPassword: true,
                  validator: passwordValidator,
                ),
                const SizedBox(height: 16),
                const TextCustom('Confirm password'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _confirm,
                  hintText: '********',
                  isPassword: true,
                  validator: (v) => (v == null || v.isEmpty)
                      ? 'Please confirm password'
                      : null,
                ),
                const SizedBox(height: 24),
                BtnFrave(text: 'Register', onPressed: _submit),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TextCustom('Already have an account? '),
                    InkWell(
                      onTap: () => context.go('/login'),
                      child: const TextCustom(
                        'Sign in',
                        color: ColorsFrave.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
