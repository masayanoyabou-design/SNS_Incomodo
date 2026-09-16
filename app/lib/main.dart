import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/user_provider.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/profile_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Incomodo',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown)),
      home: const AuthGate(),
    );
  }
}

/// Routes between signing in, the one-time profile setup, and the app.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const loading = Scaffold(body: Center(child: CircularProgressIndicator()));

    return ref.watch(authStateProvider).when(
          loading: () => loading,
          error: (error, _) => _error(error),
          data: (user) {
            if (user == null) return const LoginScreen();
            return ref.watch(myProfileProvider).when(
                  loading: () => loading,
                  error: (error, _) => _error(error),
                  data: (profile) => profile == null
                      ? const ProfileSetupScreen()
                      : const HomeScreen(),
                );
          },
        );
  }

  Widget _error(Object error) =>
      Scaffold(body: Center(child: Text('エラーが発生しました: $error')));
}
