import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'domain/bloc/auth/auth_bloc.dart';
import 'domain/services/auth_service.dart';
import 'presentation/themes/colors_frave.dart';
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (_) => AuthBloc(authService: AuthService()),
        ),
      ],
      child: MaterialApp.router(
        title: 'Delicia',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primaryColor: ColorsFrave.primaryColor,
          colorScheme: ColorScheme.fromSeed(
            seedColor: ColorsFrave.primaryColor,
          ),
          scaffoldBackgroundColor: Colors.white,
          useMaterial3: true,
        ),
        routerConfig: AppRouter.router,
      ),
    );
  }
}
