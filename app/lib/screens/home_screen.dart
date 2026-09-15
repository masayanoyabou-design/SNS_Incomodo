import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Incomodo')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ようこそ、${user?.displayName ?? user?.email ?? 'ゲスト'}さん'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(authServiceProvider).signOut(),
              child: const Text('ログアウト'),
            ),
          ],
        ),
      ),
    );
  }
}
