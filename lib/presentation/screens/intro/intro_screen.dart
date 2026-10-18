import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/login'),
                  child: const TextCustom(
                    'Skip',
                    color: ColorsFrave.greyText,
                  ),
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.delivery_dining,
                size: 140,
                color: ColorsFrave.primaryColor,
              ),
              const SizedBox(height: 24),
              const TextCustom(
                'Delicia',
                fontSize: 36,
                fontWeight: FontWeight.bold,
                textAlign: TextAlign.center,
                color: ColorsFrave.primaryColor,
              ),
              const SizedBox(height: 8),
              const TextCustom(
                'Food delivered to your door.\nFresh, fast, friendly.',
                textAlign: TextAlign.center,
                color: ColorsFrave.greyText,
              ),
              const Spacer(),
              BtnFrave(
                text: 'Sign in with Email',
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 12),
              BtnFrave(
                text: 'Create an account',
                color: Colors.white,
                textColor: ColorsFrave.primaryColor,
                onPressed: () => context.push('/register'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
