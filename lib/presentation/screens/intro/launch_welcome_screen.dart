import 'package:flutter/material.dart';

import 'widgets/launch_welcome_view.dart';

/// Launch Welcome Screen — the orange screen that follows the splash.
///
/// Flow contract:
///   • Always reached from `/splash` once the session check resolves.
///   • Primary pill → `/login` (existing account).
///   • Secondary pill → `/register` (new account).
class LaunchWelcomeScreen extends StatefulWidget {
  const LaunchWelcomeScreen({super.key});

  @override
  State<LaunchWelcomeScreen> createState() => _LaunchWelcomeScreenState();
}

class _LaunchWelcomeScreenState extends State<LaunchWelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LaunchWelcomeView(animation: _intro);
}