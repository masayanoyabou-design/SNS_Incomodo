import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';

/// Shown in place of the app to an account the operator has suspended
/// after a report (B35). The rules refuse its letters and friend requests
/// whatever the app does; this says why, and where to ask.
class SuspendedScreen extends ConsumerWidget {
  const SuspendedScreen({super.key});

  static const contact = 'incomodo.app@gmail.com';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block, size: 48),
                const SizedBox(height: 16),
                Text('このアカウントは利用停止中です', style: text.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  '利用規約に反する行為があったため、手紙の送信と友だちリクエストを停止しています。'
                  'お心当たりがない場合や、アカウントの削除をご希望の場合は、下記までご連絡ください。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const SelectableText(contact),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => ref.read(authServiceProvider).signOut(),
                  child: const Text('ログアウト'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
