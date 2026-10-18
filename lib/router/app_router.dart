import 'package:go_router/go_router.dart';

import '../../domain/models/category.dart';
import '../presentation/screens/intro/checking_login_screen.dart';
import '../presentation/screens/intro/intro_screen.dart';
import '../presentation/screens/login/check_email_screen.dart';
import '../presentation/screens/login/forgot_password_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/login/register_client_screen.dart';
import '../presentation/screens/home/select_role_screen.dart';
import '../presentation/screens/home/home_placeholder.dart';
import '../presentation/client/home/home_screen.dart';
import '../presentation/client/search/search_for_category_screen.dart';
import '../presentation/client/product_detail/product_detail_screen.dart';
import '../presentation/client/cart/cart_screen.dart';
import '../presentation/client/checkout/checkout_screen.dart';
import '../presentation/client/map/map_client_screen.dart';
import '../presentation/client/orders/orders_screen.dart';
import '../presentation/delivery/map/map_delivery_screen.dart';

/// App router (GoRouter). Wires the UC-01 auth flow plus the Leader's
/// UC-02/03/04 client/delivery screens. Admin/delivery role homes stay
/// as placeholders until Member B/C merge their respective UCs.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // ---- Auth flow (UC-01) ------------------------------------------------
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

      // ---- Client flow (UC-02 / UC-04 / UC-03) -----------------------------
      GoRoute(
        path: '/client/home',
        builder: (_, __) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/client/search-category',
        builder: (_, state) {
          final extra = state.extra;
          return SearchForCategoryScreen(
            category: extra is Category ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/client/details-product/:id',
        builder: (_, state) => ProductDetailScreen(
          productId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/client/cart',
        builder: (_, __) => const CartScreen(),
      ),
      GoRoute(
        path: '/client/checkout',
        builder: (_, __) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/client/orders',
        builder: (_, __) => const ClientOrdersScreen(),
      ),
      GoRoute(
        path: '/client/map',
        builder: (_, __) => const MapClientScreen(),
      ),

      // ---- Delivery flow (UC-03) ------------------------------------------
      GoRoute(
        path: '/delivery/map/:orderId',
        builder: (_, state) => MapDeliveryScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),

      // ---- Placeholders (other members) -----------------------------------
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