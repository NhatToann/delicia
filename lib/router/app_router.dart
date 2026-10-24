import 'package:go_router/go_router.dart';

import '../../domain/models/category.dart';
import '../../domain/models/client_address.dart';
import '../../domain/models/order_record.dart';
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
import '../presentation/client/orders/order_detail_screen.dart';
import '../presentation/client/orders/orders_list_screen.dart';
import '../presentation/client/address/select_address_screen.dart';
import '../presentation/client/profile/address_form_screen.dart';
import '../presentation/client/profile/address_list_screen.dart';
import '../presentation/client/profile/profile_screen.dart';
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
        builder: (_, _) => const CheckingLoginScreen(),
      ),
      GoRoute(path: '/intro', builder: (_, _) => const IntroScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (_, _) => const RegisterClientScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (_, _) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (_, _) => const SelectRoleScreen(),
      ),

      // ---- Client flow (UC-02 / UC-03 / UC-04 / UC-05 / UC-06) -----------
      GoRoute(
        path: '/client/home',
        builder: (_, _) => const ClientHomeScreen(),
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
      GoRoute(path: '/client/cart', builder: (_, _) => const CartScreen()),
      GoRoute(
        path: '/client/checkout',
        builder: (_, _) => const CheckoutScreen(),
      ),

      // UC-05 — orders list + detail (Member A). The list replaces the
      // old placeholder: it shows the active orders and the full history
      // with a per-order detail screen.
      GoRoute(
        path: '/client/orders',
        builder: (_, _) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/client/orders/detail/:id',
        builder: (_, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          return OrderDetailScreen(
            orderId: id,
            initialOrder: extra is OrderRecord ? extra : null,
          );
        },
      ),
      // Keeps the Leader's "order placed" placeholder reachable without
      // hijacking the UC-05 list route.
      GoRoute(
        path: '/client/orders/last-order',
        builder: (_, _) => const ClientOrdersScreen(),
      ),

      // UC-06 — profile + addresses.
      GoRoute(
        path: '/client/profile',
        builder: (_, _) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses',
        builder: (_, _) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses/new',
        builder: (_, _) => const AddressFormScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses/edit/:id',
        builder: (_, state) {
          final extra = state.extra;
          return AddressFormScreen(
            existingAddress: extra is ClientAddress ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/client/select-address',
        builder: (_, _) => const SelectAddressScreen(),
      ),
      GoRoute(
        path: '/client/map',
        builder: (_, _) => const MapClientScreen(),
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
        builder: (_, _) => const HomePlaceholder(label: 'Admin Home (UC-08)'),
      ),
      GoRoute(
        path: '/delivery/home',
        builder: (_, _) =>
            const HomePlaceholder(label: 'Delivery Home (UC-10)'),
      ),
    ],
  );
}
