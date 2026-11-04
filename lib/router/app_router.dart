import 'package:go_router/go_router.dart';

import '../../domain/models/category.dart';
import '../../domain/models/client_address.dart';
import '../../domain/models/order_record.dart';
import '../presentation/admin/categories/category_form_screen.dart';
import '../presentation/admin/categories/category_list_screen.dart';
import '../presentation/admin/dashboard/dashboard_screen.dart';
import '../presentation/admin/delivery/delivery_users_screen.dart';
import '../presentation/admin/delivery/driver_form_screen.dart';
import '../presentation/admin/orders/new_orders_screen.dart';
import '../presentation/admin/orders/order_detail_admin_screen.dart';
import '../presentation/admin/orders/orders_management_screen.dart';
import '../presentation/admin/products/product_form_screen.dart';
import '../presentation/admin/products/product_list_screen.dart';
import '../presentation/client/address/select_address_screen.dart';
import '../presentation/client/cart/cart_screen.dart';
import '../presentation/client/home/home_screen.dart';
import '../presentation/client/map/map_client_screen.dart';
import '../presentation/client/orders/order_detail_screen.dart';
import '../presentation/client/orders/orders_list_screen.dart';
import '../presentation/client/orders/orders_screen.dart';
import '../presentation/client/payment/payment_screen.dart';
import '../presentation/client/product_detail/product_detail_screen.dart';
import '../presentation/client/profile/address_form_screen.dart';
import '../presentation/client/profile/address_list_screen.dart';
import '../presentation/client/profile/profile_screen.dart';
import '../presentation/client/search/search_for_category_screen.dart';
import '../presentation/delivery/details/delivery_details_screen.dart';
import '../presentation/delivery/home/delivery_home_screen.dart';
import '../presentation/delivery/map/map_delivery_screen.dart';
import '../presentation/delivery/profile/delivery_profile_screen.dart';
import '../presentation/screens/home/select_role_screen.dart';
import '../presentation/screens/intro/launch_first_screen.dart';
import '../presentation/screens/intro/launch_welcome_screen.dart';
import '../presentation/screens/login/check_email_screen.dart';
import '../presentation/screens/login/forgot_password_screen.dart';
import '../presentation/screens/login/login_screen.dart';
import '../presentation/screens/login/register_client_screen.dart';

/// App router (GoRouter). Wires the UC-01 auth flow plus the Leader's
/// UC-02/03/04 client/delivery screens, the UC-05/06 client screens and the
/// UC-07/08/09 admin screens.
class AppRouter {
  AppRouter._();

  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      // ---- Launch flow (UC-01) ---------------------------------------------
      // Splash ("Launch First") always runs first, then resolves into either
      // the role destination (session alive) or "Launch Welcome" (`/intro`).
      GoRoute(
        path: '/splash',
        builder: (_, __) => const LaunchFirstScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (_, __) => const LaunchWelcomeScreen(),
      ),
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

      // ---- Client flow (UC-02 / UC-03 / UC-04 / UC-05 / UC-06) -----------
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
        path: '/client/payment',
        builder: (_, __) => const PaymentScreen(),
      ),
      // UC-05 — orders list (the Figma-aligned screen that ships in main).
      GoRoute(
        path: '/client/orders',
        builder: (_, __) => const ClientOrdersView(),
      ),
      // UC-05 — the realtime order list + the order detail screen.
      GoRoute(
        path: '/client/orders/list',
        builder: (_, __) => const OrdersListScreen(),
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

      // UC-06 — profile + addresses.
      GoRoute(
        path: '/client/profile',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/edit',
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses',
        builder: (_, __) => const AddressListScreen(),
      ),
      GoRoute(
        path: '/client/profile/addresses/new',
        builder: (_, __) => const AddressFormScreen(),
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
        builder: (_, __) => const SelectAddressScreen(),
      ),
      GoRoute(
        path: '/client/map',
        builder: (_, __) => const MapClientScreen(),
      ),

      // ---- Delivery flow (UC-03 / UC-10 / UC-11) --------------------------
      GoRoute(
        path: '/delivery/home',
        builder: (_, __) => const DeliveryHomeScreen(),
      ),
      GoRoute(
        path: '/delivery/details/:orderId',
        builder: (_, state) => DeliveryDetailsScreen(
          orderId: state.pathParameters['orderId'] ?? '',
          order: state.extra is OrderRecord ? state.extra as OrderRecord : null,
        ),
      ),
      GoRoute(
        path: '/delivery/map/:orderId',
        builder: (_, state) => MapDeliveryScreen(
          orderId: state.pathParameters['orderId'] ?? '',
        ),
      ),
      GoRoute(
        path: '/delivery/profile',
        builder: (_, __) => const DeliveryProfileScreen(),
      ),

      // ---- Admin flow (UC-07 / UC-08 / UC-09) ------------------------------
      GoRoute(
        path: '/admin/home',
        builder: (_, __) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/admin/categories',
        builder: (_, __) => const AdminCategoryListScreen(),
      ),
      GoRoute(
        path: '/admin/categories/new',
        builder: (_, __) => const AdminCategoryFormScreen(),
      ),
      GoRoute(
        path: '/admin/categories/:id',
        builder: (_, state) => AdminCategoryFormScreen(
          categoryId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/products',
        builder: (_, __) => const AdminProductListScreen(),
      ),
      GoRoute(
        path: '/admin/products/new',
        builder: (_, __) => const AdminProductFormScreen(),
      ),
      GoRoute(
        path: '/admin/products/:id',
        builder: (_, state) => AdminProductFormScreen(
          productId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/orders',
        builder: (_, __) => const AdminOrdersManagementScreen(),
      ),
      // The "new orders" screen has to be declared *before* the `:id`
      // route — otherwise GoRouter would match `/admin/orders/new` as
      // an order id and the detail screen would open for a phantom
      // order.
      GoRoute(
        path: '/admin/orders/new',
        builder: (_, __) => const AdminNewOrdersScreen(),
      ),
      GoRoute(
        path: '/admin/orders/:id',
        builder: (_, state) => AdminOrderDetailScreen(
          orderId: state.pathParameters['id'] ?? '',
        ),
      ),
      GoRoute(
        path: '/admin/delivery',
        builder: (_, __) => const AdminDeliveryUsersScreen(),
      ),
      // The "new driver" screen is declared *before* the list route is
      // reachable — GoRouter matches the exact path first, so a separate
      // entry is enough.
      GoRoute(
        path: '/admin/delivery/new',
        builder: (_, __) => const AdminDriverFormScreen(),
      ),
    ],
  );
}
