import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import '../widgets/postmark.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isSigningIn = false;
  String? _errorMessage;

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });
    try {
      await ref.read(authServiceProvider).signInWithGoogle();
    } catch (e) {
      setState(() => _errorMessage = 'ログインに失敗しました: $e');
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Postmark(date: DateTime.now(), size: 96),
              const SizedBox(height: 28),
              Text(
                'Incomodo',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'インコモード',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.secondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 20),
              Text('行かなきゃ、読めない。', style: theme.textTheme.titleMedium),
              const SizedBox(height: 48),
              if (_isSigningIn)
                const CircularProgressIndicator()
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _handleGoogleSignIn,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Text('Googleでログイン'),
                    ),
                  ),
                ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: TextStyle(color: theme.colorScheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
