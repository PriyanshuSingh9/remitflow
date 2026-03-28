import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/app_data_service.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.surfaceContainerLowest,
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
      home: const _AppGate(),
    );
  }
}

class _AppGate extends StatefulWidget {
  const _AppGate();

  @override
  State<_AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<_AppGate> {
  bool _bootstrapQueued = false;

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final appData = AppDataService();

    return ListenableBuilder(
      listenable: Listenable.merge([auth, appData]),
      builder: (context, _) {
        if (!auth.isAuthenticated) {
          _bootstrapQueued = false;
          if (appData.hasSession) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              appData.clear();
            });
          }
          return const LoginScreen();
        }

        if (appData.dashboard == null && !appData.isBootstrapping && !_bootstrapQueued) {
          _bootstrapQueued = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            _bootstrapQueued = false;
            await appData.bootstrapAuthenticatedUser();
          });
        }

        if (appData.isBootstrapping && appData.dashboard == null) {
          return const _LoadingScaffold(
            title: 'Syncing your wallet',
            message: 'We are loading your Neon-backed dashboard and recipients.',
          );
        }

        if (appData.dashboard == null) {
          return _ErrorScaffold(
            message: appData.bootstrapErrorMessage ??
                'We could not load your dashboard yet. Check the backend server and your Google sign-in session.',
            onRetry: () => appData.bootstrapAuthenticatedUser(forceRefresh: true),
            onLogout: () async {
              appData.clear();
              await auth.logout();
            },
          );
        }

        return const HomeScreen();
      },
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppTheme.vaultGreen),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorScaffold extends StatelessWidget {
  const _ErrorScaffold({
    required this.message,
    required this.onRetry,
    required this.onLogout,
  });

  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surfaceContainerLowest,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 52, color: AppTheme.secondary),
                const SizedBox(height: 20),
                Text(
                  'Backend sync failed',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => onRetry(),
                    child: const Text('Retry'),
                  ),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => onLogout(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
