import 'package:go_router/go_router.dart';

import '../presentation/screens/intro/checking_login_screen.dart';
import '../presentation/screens/intro/intro_screen.dart';
import '../presentation/screens/login/check_email_screen.dart';
import '../presentation/screens/login/forgot_password_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/login/register_client_screen.dart';
import '../presentation/screens/home/select_role_screen.dart';
import '../presentation/screens/home/home_placeholder.dart';

/// App router (GoRouter). Use case 01 only needs the auth flow; admin / client
/// / delivery homes are placeholders to be replaced in later use cases.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const CheckingLoginScreen(),
      ),
      GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterClientScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (_, __) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (_, __) => const SelectRoleScreen(),
      ),
      GoRoute(
        path: '/client/home',
        builder: (_, __) => const HomePlaceholder(label: 'Client Home (UC-02)'),
      ),
      GoRoute(
        path: '/admin/home',
        builder: (_, __) => const HomePlaceholder(label: 'Admin Home (UC-08)'),
      ),
      GoRoute(
        path: '/delivery/home',
        builder: (_, __) =>
            const HomePlaceholder(label: 'Delivery Home (UC-10)'),
      ),
    ],
  );
}
