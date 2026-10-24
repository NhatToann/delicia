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
    context.read<AuthBloc>().add(ForgotPasswordEvent(_email.text));
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
        } else if (state is ForgotPasswordSuccessState) {
          Navigator.of(context, rootNavigator: true).pop();
          context.push('/check-email');
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Form(
            key: _keyForm,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(height: 16),
                const TextCustom(
                  'Reset your password',
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 8),
                const TextCustom(
                  'We will email you a link to reset your password.',
                  color: ColorsFrave.greyText,
                ),
                const SizedBox(height: 24),
                const TextCustom('Email'),
                const SizedBox(height: 8),
                FormFieldFrave(
                  controller: _email,
                  hintText: 'email@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: validatedEmail,
                ),
                const SizedBox(height: 24),
                BtnFrave(text: 'Send reset link', onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
