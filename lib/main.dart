import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'domain/bloc/address/address_bloc.dart';
import 'domain/bloc/auth/auth_bloc.dart';
import 'domain/bloc/cart/cart_bloc.dart';
import 'domain/bloc/client_orders/client_orders_bloc.dart';
import 'domain/bloc/map_client/map_client_bloc.dart';
import 'domain/bloc/map_delivery/map_delivery_bloc.dart';
import 'domain/bloc/orders/orders_bloc.dart';
import 'domain/bloc/payment/payment_bloc.dart';
import 'domain/bloc/products/products_bloc.dart';
import 'domain/bloc/user/user_bloc.dart';
import 'domain/services/auth_service.dart';
import 'domain/services/client_address_service.dart';
import 'domain/services/client_orders_service.dart';
import 'domain/services/client_user_service.dart';
import 'domain/services/firebase_orders_service.dart';
import 'domain/services/orders_service.dart';
import 'domain/services/payment_gateway.dart';
import 'domain/services/products_service.dart'
    show FirebaseCategoryService, FirebaseProductsService;
import 'domain/services/realtime_service.dart';
import 'l10n/generated/app_localizations.dart';
import 'presentation/themes/colors_frave.dart';
import 'presentation/themes/type_frave.dart';
import 'router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const DeliciaApp());
}

class DeliciaApp extends StatelessWidget {
  const DeliciaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Single source of truth for the orders service so the bloc hierarchy
    // below and the order-detail screen (which consumes the service
    // directly via context.read) both see the same instance.
    final ordersService = FirebaseOrdersService();
    final clientOrdersService = FirebaseClientOrdersService();
    final userService = FirebaseClientUserService();
    final addressService = FirebaseClientAddressService();

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<OrdersService>.value(value: ordersService),
        RepositoryProvider<ClientOrdersService>.value(
          value: clientOrdersService,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthBloc>(
            create: (_) => AuthBloc(authService: AuthService()),
          ),
          BlocProvider<ProductsBloc>(
            create: (_) => ProductsBloc(
              categoryService: FirebaseCategoryService(),
              productsService: FirebaseProductsService(),
            ),
          ),
          BlocProvider<CartBloc>(create: (_) => CartBloc()),
          BlocProvider<OrdersBloc>(
            create: (_) => OrdersBloc(ordersService: ordersService),
          ),
          // UC-04 — checkout / payment (Leader).
          BlocProvider<PaymentBloc>(
            create: (_) => PaymentBloc(gateway: PayOsGateway()),
          ),
          // UC-05 — read-side orders (list / detail / realtime / cancel).
          // Held separately from the Leader's OrdersBloc so checkout is
          // untouched.
          BlocProvider<ClientOrdersBloc>(
            create: (_) => ClientOrdersBloc(
              ordersService: clientOrdersService,
            ),
          ),
          BlocProvider<MapClientBloc>(
            create: (_) => MapClientBloc(realtimeService: RealtimeService()),
          ),
          BlocProvider<MapDeliveryBloc>(
            create: (_) => MapDeliveryBloc(realtimeService: RealtimeService()),
          ),
          // UC-06 — profile + address management.
          BlocProvider<UserBloc>(
            create: (_) => UserBloc(userService: userService),
          ),
          BlocProvider<AddressBloc>(
            create: (_) => AddressBloc(addressService: addressService),
          ),
        ],
        child: MaterialApp.router(
          title: 'Delicia',
          debugShowCheckedModeBanner: false,
          // Vietnamese is the product language. The generated delegate carries
          // the copy; the Material/Cupertino/Widgets delegates make the
          // built-in widgets (date pickers, selection menus) speak Vietnamese
          // too.
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
    );
  }
}
