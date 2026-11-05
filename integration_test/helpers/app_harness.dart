// Boots the **real** Delicia widget tree on top of in-memory services.
//
// The integration tests are end-to-end inside the app: the same blocs, the
// same screens, the same router and the same navigation the customer sees.
// Only the transport is swapped — Firebase is replaced by the fakes in
// `fake_services.dart` so the flow is deterministic and offline.
//
// Why not `app.main()`?
//
// `main()` calls `Firebase.initializeApp()` and wires the Firebase-backed
// services. On a CI machine (or a machine without `google-services.json`)
// that either throws or silently produces empty catalogues, which makes the
// test assert nothing. [pumpDeliciaApp] mounts the identical provider
// hierarchy with injectable services instead.

import 'package:delicia/domain/bloc/address/address_bloc.dart';
import 'package:delicia/domain/bloc/auth/auth_bloc.dart';
import 'package:delicia/domain/bloc/cart/cart_bloc.dart';
import 'package:delicia/domain/bloc/client_orders/client_orders_bloc.dart';
import 'package:delicia/domain/bloc/driver_orders/driver_orders_bloc.dart';
import 'package:delicia/domain/bloc/map_client/map_client_bloc.dart';
import 'package:delicia/domain/bloc/map_delivery/map_delivery_bloc.dart';
import 'package:delicia/domain/bloc/orders/orders_bloc.dart';
import 'package:delicia/domain/bloc/products/products_bloc.dart';
import 'package:delicia/domain/bloc/user/user_bloc.dart';
import 'package:delicia/domain/services/admin_catalog_service.dart';
import 'package:delicia/domain/services/admin_orders_service.dart';
import 'package:delicia/domain/services/auth_service.dart';
import 'package:delicia/domain/services/client_address_service.dart';
import 'package:delicia/domain/services/client_orders_service.dart';
import 'package:delicia/domain/services/client_user_service.dart';
import 'package:delicia/domain/services/orders_service.dart';
import 'package:delicia/domain/services/realtime_service.dart';
import 'package:delicia/l10n/generated/app_localizations.dart';
import 'package:delicia/presentation/components/auth_widgets.dart';
import 'package:delicia/presentation/themes/colors_frave.dart';
import 'package:delicia/presentation/themes/type_frave.dart';
import 'package:delicia/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_services.dart';

/// Everything the integration test needs to drive the app.
class IntegrationApp {
  IntegrationApp({
    required this.authService,
    required this.catalogService,
    required this.adminCatalogService,
    required this.imageUploadService,
    required this.ordersService,
    required this.adminOrdersService,
    required this.clientOrdersService,
    required this.clientUserService,
    required this.clientAddressService,
    required this.adminUsersService,
    required this.deliveryUsersService,
    required this.realtimeService,
    required this.orderStore,
  });

  final AuthService authService;
  final FakeCatalogService catalogService;
  final AdminCatalogService adminCatalogService;
  final ImageUploadService imageUploadService;
  final OrdersService ordersService;
  final AdminOrdersService adminOrdersService;
  final ClientOrdersService clientOrdersService;
  final ClientUserService clientUserService;
  final ClientAddressService clientAddressService;
  final AdminUsersService adminUsersService;
  final DeliveryUsersService deliveryUsersService;
  final RealtimeService realtimeService;
  final FakeOrderStore orderStore;

  /// Builds an app whose login resolves to a **customer** (`rolId == 1`).
  factory IntegrationApp.client() {
    final catalog = FakeCatalogService();
    final store = FakeOrderStore();
    return IntegrationApp(
      authService: FakeAuthService(rolId: 1),
      catalogService: catalog,
      adminCatalogService: FakeAdminCatalogService(catalog),
      imageUploadService: FakeImageUploadService(),
      ordersService: FakeOrdersService(store),
      adminOrdersService: FakeAdminOrdersService(store),
      clientOrdersService: FakeClientOrdersService(store),
      clientUserService: FakeClientUserService(),
      clientAddressService: FakeClientAddressService(),
      adminUsersService: FakeAdminUsersService(),
      deliveryUsersService: FakeDeliveryUsersService(),
      realtimeService: FakeRealtimeService(),
      orderStore: store,
    );
  }

  /// Builds an app whose login resolves to the **restaurant** (`rolId == 2`).
  factory IntegrationApp.admin() {
    final catalog = FakeCatalogService();
    final store = FakeOrderStore();
    return IntegrationApp(
      authService: FakeAuthService(rolId: 2),
      catalogService: catalog,
      adminCatalogService: FakeAdminCatalogService(catalog),
      imageUploadService: FakeImageUploadService(),
      ordersService: FakeOrdersService(store),
      adminOrdersService: FakeAdminOrdersService(store),
      clientOrdersService: FakeClientOrdersService(store),
      clientUserService: FakeClientUserService(),
      clientAddressService: FakeClientAddressService(),
      adminUsersService: FakeAdminUsersService(),
      deliveryUsersService: FakeDeliveryUsersService(),
      realtimeService: FakeRealtimeService(),
      orderStore: store,
    );
  }

  /// Builds an app whose login resolves to the **courier** (`rolId == 3`).
  factory IntegrationApp.delivery() {
    final catalog = FakeCatalogService();
    final store = FakeOrderStore();
    return IntegrationApp(
      authService: FakeAuthService(rolId: 3),
      catalogService: catalog,
      adminCatalogService: FakeAdminCatalogService(catalog),
      imageUploadService: FakeImageUploadService(),
      ordersService: FakeOrdersService(store),
      adminOrdersService: FakeAdminOrdersService(store),
      clientOrdersService: FakeClientOrdersService(store),
      clientUserService: FakeClientUserService(),
      clientAddressService: FakeClientAddressService(),
      adminUsersService: FakeAdminUsersService(),
      deliveryUsersService: FakeDeliveryUsersService(),
      realtimeService: FakeRealtimeService(),
      orderStore: store,
    );
  }
}

/// Mounts the app on [tester] and returns the harness.
///
/// [initialLocation] decides which route the app opens on — `/login` by
/// default, because that is where a fresh install starts.
Future<IntegrationApp> pumpDeliciaApp(
  WidgetTester tester, {
  IntegrationApp? app,
  String initialLocation = '/login',
  Size size = const Size(393, 852),
}) async {
  final harness = app ?? IntegrationApp.client();

  // The app is designed against the Figma frame (393 x 852), so the
  // integration test uses the same viewport — otherwise the pinned CTAs
  // sit below the fold and the taps miss.
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  // The router is a static singleton, so the location from a previous test
  // would still be mounted. Navigating explicitly resets it — the app
  // always starts at the login screen in a fresh install.
  AppRouter.router.go(initialLocation);

  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: <RepositoryProvider<dynamic>>[
        RepositoryProvider<AdminCatalogService>.value(
          value: harness.adminCatalogService,
        ),
        RepositoryProvider<ImageUploadService>.value(
          value: harness.imageUploadService,
        ),
        RepositoryProvider<AdminOrdersService>.value(
          value: harness.adminOrdersService,
        ),
        RepositoryProvider<AdminUsersService>.value(
          value: harness.adminUsersService,
        ),
        RepositoryProvider<DeliveryUsersService>.value(
          value: harness.deliveryUsersService,
        ),
        RepositoryProvider<OrdersService>.value(value: harness.ordersService),
        RepositoryProvider<ClientOrdersService>.value(
          value: harness.clientOrdersService,
        ),
        RepositoryProvider<ClientUserService>.value(
          value: harness.clientUserService,
        ),
        RepositoryProvider<ClientAddressService>.value(
          value: harness.clientAddressService,
        ),
      ],
      child: MultiBlocProvider(
        providers: <BlocProvider<dynamic>>[
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(authService: harness.authService),
          ),
          BlocProvider<ProductsBloc>(
            create: (_) => ProductsBloc(
              categoryService: harness.catalogService,
              productsService: harness.catalogService,
            ),
          ),
          BlocProvider<CartBloc>(create: (_) => CartBloc()),
          BlocProvider<OrdersBloc>(
            create: (_) => OrdersBloc(ordersService: harness.ordersService),
          ),
          BlocProvider<DriverOrdersBloc>(
            create: (_) => DriverOrdersBloc(
              ordersService: harness.ordersService,
            ),
          ),
          BlocProvider<ClientOrdersBloc>(
            create: (_) => ClientOrdersBloc(
              ordersService: harness.clientOrdersService,
            ),
          ),
          BlocProvider<MapClientBloc>(
            create: (_) => MapClientBloc(
              realtimeService: harness.realtimeService,
            ),
          ),
          BlocProvider<MapDeliveryBloc>(
            create: (_) => MapDeliveryBloc(
              realtimeService: harness.realtimeService,
            ),
          ),
          BlocProvider<UserBloc>(
            create: (_) => UserBloc(userService: harness.clientUserService),
          ),
          BlocProvider<AddressBloc>(
            create: (_) => AddressBloc(
              addressService: harness.clientAddressService,
            ),
          ),
        ],
        child: MaterialApp.router(
          title: 'Delicia',
          debugShowCheckedModeBanner: false,
          locale: const Locale('vi'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: ThemeData(
            primaryColor: ColorsFrave.primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: ColorsFrave.primaryColor,
            ),
            scaffoldBackgroundColor: ColorsFrave.backgroundColor,
            fontFamily: FraveText.family,
            useMaterial3: true,
          ),
          routerConfig: AppRouter.router,
        ),
      ),
    ),
  );

  // The router is a static singleton, so the location from a previous test
  // would still be mounted. Navigating explicitly resets it — the app
  // always starts at the login screen in a fresh install.
  AppRouter.router.go(initialLocation);
  await tester.pumpAndSettle();
  return harness;
}

/// Pumps a fixed number of frames.
///
/// The admin screens show a `CircularProgressIndicator` while the order
/// feed loads. The spinner schedules frames forever, so `pumpAndSettle`
/// spins until the test times out. Pumping a fixed number of frames
/// flushes the pending microtasks and can never hang.
Future<void> pumpFrames(
  WidgetTester tester, {
  int frames = 14,
  Duration step = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(step);
  }
}

/// Signs in through the real login form.
///
/// The test types into the actual fields and taps the actual button, so
/// the validation, the bloc and the redirect are all exercised.
Future<void> signIn(
  WidgetTester tester, {
  String email = 'khach@delicia.com',
  String password = '123456',
}) async {
  final emailField = find.byType(TextFormField).first;
  final passwordField = find.byType(TextFormField).last;

  await tester.enterText(emailField, email);
  await tester.enterText(passwordField, password);
  await tester.pump();

  // The submit button is the primary CTA — the "Đăng nhập" copy also
  // appears in the page title, so the button is addressed by its type.
  await tester.tap(find.byType(AuthPrimaryButton));
  await pumpFrames(tester);
}
