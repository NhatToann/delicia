import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../domain/bloc/auth/auth_bloc.dart';
import 'widgets/launch_first_view.dart';

/// Launch First Screen — the yellow splash that opens the app.
///
/// Design reference: `assets/.../0 - A - Launch First Screen.png`
/// (393x852, yellow #F5CB58, orange #FF642F mark, orange round CTA).
///
/// Flow contract:
///   • Always shown first (GoRouter `initialLocation`).
///   • [CheckLoginEvent] is dispatched on the first frame so the answer is
///     ready before the splash finishes its entrance animation.
///   • The splash stays on screen for at least [minVisible] — this is why
///     users always see the yellow brand screen, never a flash of Welcome.
///   • Logged in            → role destination (immediately, no delay).
///   • Logged out           → /intro (Launch Welcome) after [minVisible].
///   • Session check stalls → /intro after [minVisible] + [checkGrace].
class LaunchFirstScreen extends StatefulWidget {
  const LaunchFirstScreen({super.key});

  /// Minimum time the splash must stay visible before auto-routing.
  static const Duration minVisible = Duration(milliseconds: 2200);

  /// Extra time we grant the session check once [minVisible] has elapsed.
  /// If Firebase is slow we still land on Welcome rather than trapping the
  /// user on a splash that never resolves.
  static const Duration checkGrace = Duration(milliseconds: 1800);

  @override
  State<LaunchFirstScreen> createState() => _LaunchFirstScreenState();
}

class _LaunchFirstScreenState extends State<LaunchFirstScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  Timer? _defer;
  bool _navigated = false;

  /// True once the session check has produced a verdict (either way).
  bool _resolved = false;

  /// The signed-in user's role, captured when the check succeeds.
  String? _rolId;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    // Give the splash its full visible window, then route.
    _scheduleTransition(LaunchFirstScreen.minVisible);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Probe the session immediately; the listener below will react.
      context.read<AuthBloc>().add(CheckLoginEvent());
    });
  }

  @override
  void dispose() {
    _defer?.cancel();
    _intro.dispose();
    super.dispose();
  }

  String _destinationFor(String rolId) => switch (rolId) {
        '1' || '3' => '/select-role',
        '2' => '/client/home',
        _ => '/intro',
      };

  void _goTo(String location) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(location);
  }

  void _scheduleTransition(Duration after) {
    _defer?.cancel();
    _defer = Timer(after, () {
      if (_navigated || !mounted) return;
      final rolId = _rolId;
      if (rolId != null && rolId.isNotEmpty) {
        _goTo(_destinationFor(rolId));
        return;
      }
      // Not logged in (or the check is still in flight). Grant the session
      // probe a short grace period before falling through to Welcome.
      if (!_resolved) {
        _scheduleTransition(LaunchFirstScreen.checkGrace);
        return;
      }
      _goTo('/intro');
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listenWhen: (previous, current) =>
          current is LogOutAuthState ||
          (current.runtimeType.toString() == 'AuthState' &&
              current.rolId.isNotEmpty),
      listener: (context, state) {
        _resolved = true;
        if (state is LogOutAuthState) {
          _rolId = null;
          return; // routing is handled by [_scheduleTransition]
        }
        // Logged in: go straight to the role destination. There's no point
        // gating the home screen behind the splash's animation budget.
        final rolId = state.rolId;
        _defer?.cancel();
        _goTo(_destinationFor(rolId));
      },
      child: LaunchFirstView(
        animation: _intro,
        onContinue: () {
          _defer?.cancel();
          _goTo('/intro');
        },
      ),
    );
  }
}