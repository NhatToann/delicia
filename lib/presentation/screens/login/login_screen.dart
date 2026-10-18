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
    context.read<AuthBloc>().add(LoginEvent(_email.text, _password.text));
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
        } else if (state is AuthState && state.rolId.isNotEmpty) {
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
                const SizedBox(height: 16),
                const Icon(
                  Icons.restaurant,
                  size: 96,
                  color: ColorsFrave.primaryColor,
                ),
                const SizedBox(height: 16),
                const TextCustom(
                  'Welcome back!',
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const TextCustom(
                  'Use your credentials below and login to your account.',
                  textAlign: TextAlign.center,
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 40),
                const TextCustom('Email Address'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _email,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: validatedEmail,
                ),
                const SizedBox(height: 20),
                const TextCustom('Password'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _password,
                  hintText: '********',
                  isPassword: true,
                  validator: passwordValidator,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push('/forgot-password'),
                    child: const TextCustom(
                      'Forgot Password?',
                      color: ColorsFrave.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                BtnFrave(text: 'Login', onPressed: _submit),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const TextCustom("Don't have an account? "),
                    InkWell(
                      onTap: () => context.push('/register'),
                      child: const TextCustom(
                        'Sign up',
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
