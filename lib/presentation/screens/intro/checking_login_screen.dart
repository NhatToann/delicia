import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import '../../../presentation/themes/colors_frave.dart';

class CheckingLoginScreen extends StatefulWidget {
  const CheckingLoginScreen({super.key});

  @override
  State<CheckingLoginScreen> createState() => _CheckingLoginScreenState();
}

class _CheckingLoginScreenState extends State<CheckingLoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthBloc>().add(CheckLoginEvent());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is LogOutAuthState) {
          context.go('/intro');
        } else if (state is AuthState && state.rolId.isNotEmpty) {
          switch (state.rolId) {
            case '1':
              context.go('/select-role');
              break;
            case '2':
              context.go('/client/home');
              break;
            case '3':
              context.go('/select-role');
              break;
            default:
              context.go('/intro');
          }
        }
        // TEMP-FIX: when AuthBloc emits LoadingAuthState (e.g. during the
        // initial CheckLoginEvent for a logged-out user, where the state
        // is Loading with empty rolId), kick the user to /intro so the
        // splash screen is not stuck indefinitely.  This is a workaround
        // for a missing LogOutAuthState emission in CheckLoginEvent.
        else if (state is LoadingAuthState) {
          // Only redirect once — guard with a static flag on the state
          // to avoid bouncing between /splash and /intro.
          _SplashGuard.maybeRedirectToIntro(context);
        }
      },
      builder: (_, __) => Scaffold(
        backgroundColor: ColorsFrave.primaryColor,
        body: Center(
          child: ScaleTransition(
            scale: _scale,
            child: const Icon(
              Icons.local_pizza_rounded,
              size: 120,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// TEMP-FIX: tiny helper that ensures we only push the /intro route once
/// per app session, so a re-emitted LoadingAuthState can't bounce the
/// user back from /intro to /splash.
class _SplashGuard {
  _SplashGuard._();
  static bool _redirected = false;
  static void maybeRedirectToIntro(BuildContext context) {
    if (_redirected) return;
    _redirected = true;
    // Defer to the next frame so we don't navigate while the splash
    // is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/intro');
    });
  }
}
