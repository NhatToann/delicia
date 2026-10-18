import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../components/btn_frave.dart';
import '../../components/text_custom.dart';
import '../../themes/colors_frave.dart';

/// Temporary screen used as the destination for `/client/home`, `/admin/home`
/// and `/delivery/home` until those use cases (02 / 08 / 10) are implemented.
class HomePlaceholder extends StatelessWidget {
  final String label;
  const HomePlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LogOutAuthState) {
          // Push the user back to the auth flow after Firebase has signed
          // them out.  Using `go` replaces the current route — important
          // because the back-button must not return to the role home.
          context.go('/intro');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: ColorsFrave.primaryColor,
          title: const TextCustom('Delicia', color: Colors.white),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const TextCustom(
                  'Auth flow complete!',
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                const SizedBox(height: 12),
                TextCustom(label, fontSize: 16, color: ColorsFrave.greyText),
                const SizedBox(height: 32),
                BtnFrave(
                  text: 'Sign out',
                  onPressed: () {
                    // The BLoC fires `LogOutAuthState` which the listener
                    // above picks up to navigate.  This works correctly
                    // with GoRouter (unlike Navigator.popUntil which can't
                    // pop GoRouter-managed routes).
                    context.read<AuthBloc>().add(LogOutEvent());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
