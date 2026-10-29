import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/auth_widgets.dart';
import '../../helpers/l10n_extension.dart';
import '../../themes/colors_frave.dart';

/// CheckEmailScreen — email verification success screen.
///
/// Flow contract:
///   • Reached from `/forgot-password` after a successful reset request.
///   • "Back to login" → /login.
///   • "Resend link"  → AuthBloc `ForgotPasswordEvent('', ...)`
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
    context.read<AuthBloc>().add(ForgotPasswordEvent(''));
    setState(() => _seconds = 60);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorsFrave.authBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AuthHeader(
              title: context.l10n.authCheckEmailTitle,
              onBack: () => context.go('/login'),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: ColorsFrave.successColor.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mark_email_read_outlined,
                          size: 48,
                          color: ColorsFrave.successColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      context.l10n.authCheckEmailHeadline,
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
                      context.l10n.authCheckEmailDescription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                        color: ColorsFrave.authInkSoft,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_seconds > 0)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ColorsFrave.surfaceVariant,
                            borderRadius: BorderRadius.circular(RadiusFrave.button),
                          ),
                          child: Text(
                            context.l10n.authResendIn(_seconds),
                            style: const TextStyle(
                              color: ColorsFrave.authInkSoft,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    else
                      AuthSecondaryButton(
                        label: context.l10n.actionResendLink,
                        icon: Icons.refresh_rounded,
                        onPressed: _resend,
                      ),
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(
                          foregroundColor: ColorsFrave.authAccent,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        ),
                        child: Text(
                          context.l10n.authBackToLogin,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
