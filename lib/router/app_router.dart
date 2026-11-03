import 'package:go_router/go_router.dart';

import '../../domain/models/category.dart';
import '../../domain/models/client_address.dart';
import '../../domain/models/order_record.dart';
import '../presentation/screens/intro/launch_first_screen.dart';
import '../presentation/screens/intro/launch_welcome_screen.dart';
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
import '../presentation/client/payment/payment_screen.dart';
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
/// UC-02/03/04 client/delivery screens and the UC-05/06 client screens.
/// Admin/delivery role homes stay as placeholders until Member B/C merge
/// their respective UCs.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      // ---- Launch flow (UC-01) ---------------------------------------------
      // Splash ("Launch First") always runs first, then resolves into either
      // the role destination (session alive) or "Launch Welcome" (`/intro`).
      GoRoute(
        path: '/splash',
        builder: (context, state) => const LaunchFirstScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const LaunchWelcomeScreen(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterClientScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/check-email',
        builder: (context, state) => const CheckEmailScreen(),
      ),
      GoRoute(
        path: '/select-role',
        builder: (context, state) => const SelectRoleScreen(),
      ),

      // ---- Client flow (UC-02 / UC-03 / UC-04 / UC-05 / UC-06) -----------
      GoRoute(
        path: '/client/home',
        builder: (context, state) => const ClientHomeScreen(),
      ),
      GoRoute(
        path: '/client/search-category',
        builder: (context, state) {
          final extra = state.extra;
          return SearchForCategoryScreen(
            category: extra is Category ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/client/details-product/:id',
        builder: (context, state) => ProductDetailScreen(
          productId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(path: '/client/cart', builder: (context, state) => const CartScreen()),
      GoRoute(
        path: '/client/payment',
        builder: (context, state) => const PaymentScreen(),
      ),

      // UC-05 — orders list + detail (Member A).
      GoRoute(
        path: '/client/orders',
        builder: (context, state) => const OrdersListScreen(),
      ),
      GoRoute(
        path: '/client/orders/detail/:id',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          final extra = state.extra;
          return OrderDetailScreen(
            orderId: id,
            initialOrder: extra is OrderRecord ? extra : null,
          );
        },
      ),
      GoRoute(
        path: '/client/orders/list',
        builder: (context, state) => const ClientOrdersView(),
      ),

      // UC-06 — profile + addresses (Đã gộp MyProfileScreen vào ProfileScreen).
      GoRoute(
        path: '/client/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/edit',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses',
        builder: (context, state) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses/new',
        builder: (context, state) => const AddressFormScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses/edit/:id',
        builder: (context, state) {
          final extra = state.extra;
          return AddressFormScreen(
            existingAddress: extra is ClientAddress ? extra : null,
          );
        },
      ),

      GoRoute(
        path: '/client/select-address',
        builder: (context, state) => const SelectAddressScreen(),
      ),
      GoRoute(
        path: '/client/map',
        builder: (context, state) => const MapClientScreen(),
      ),

      // ---- Delivery flow (UC-03) ------------------------------------------
      GoRoute(
        path: '/delivery/map/:orderId',
        builder: (context, state) => MapDeliveryScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),

      // ---- Placeholders (other members) -----------------------------------
      GoRoute(
        path: '/admin/home',
        builder: (context, state) => const HomePlaceholder(label: 'Admin Home (UC-08)'),
      ),
      GoRoute(
        path: '/delivery/home',
        builder: (context, state) =>
        const HomePlaceholder(label: 'Delivery Home (UC-10)'),
      ),
    ],
  );
}