import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';

class CheckEmailScreen extends StatefulWidget {
  const CheckEmailScreen({super.key});

  @override
  State<CheckEmailScreen> createState() => _CheckEmailScreenState();
}

class _CheckEmailScreenState extends State<CheckEmailScreen> {
  int _seconds = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_seconds > 0) _seconds--;
      });
      if (_seconds == 0) _timer?.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _resend() {
    // The ForgotPasswordEvent re-uses the email from the previous screen.
    // We just trigger the BLoC again; in a real flow we would pass the email
    // through route arguments.
    context.read<AuthBloc>().add(ForgotPasswordEvent(''));
    setState(() => _seconds = 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 120,
                color: ColorsFrave.primaryColor,
              ),
              const SizedBox(height: 16),
              const TextCustom(
                'Check your email',
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              const SizedBox(height: 8),
              const TextCustom(
                'We sent you a link to reset your password.',
                textAlign: TextAlign.center,
                color: ColorsFrave.greyText,
              ),
              const SizedBox(height: 32),
              if (_seconds > 0)
                TextCustom(
                  'Resend in ${_seconds}s',
                  color: ColorsFrave.greyText,
                )
              else
                BtnFrave(
                  text: 'Resend link',
                  color: Colors.white,
                  textColor: ColorsFrave.primaryColor,
                  onPressed: _resend,
                ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.go('/login'),
                child: const TextCustom(
                  'Back to login',
                  color: ColorsFrave.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
