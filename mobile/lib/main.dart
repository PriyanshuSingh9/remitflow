import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceContainerLowest, // Match Login and Home bottom backgrounds
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  await AuthService().init();

  runApp(const RemitFlowApp());
}

class RemitFlowApp extends StatelessWidget {
  const RemitFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RemitFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: ListenableBuilder(
        listenable: AuthService(),
        builder: (context, _) {
          if (AuthService().isAuthenticated) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}
