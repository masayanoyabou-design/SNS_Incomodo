import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

/// Shown once, right after the first sign-in: pick the name that appears
/// on your letters and the ID friends use to find you.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  late final _nameController = TextEditingController(
    text: ref.read(authStateProvider).value?.displayName ?? '',
  );
  final _handleController = TextEditingController();
  String? _nameError;
  String? _handleError;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final nameError = UserProfile.validateDisplayName(_nameController.text);
    final handleError = UserProfile.validateHandle(_handleController.text);
    setState(() {
      _nameError = nameError;
      _handleError = handleError;
    });
    if (nameError != null || handleError != null) return;

    setState(() => _saving = true);
    try {
      await ref.read(userServiceProvider).createProfile(
            uid: ref.read(authStateProvider).value!.uid,
            displayName: _nameController.text,
            handle: _handleController.text,
          );
    } catch (e) {
      debugPrint('Profile setup failed: $e');
      if (mounted) setState(() => _handleError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('はじめの設定'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('手紙に表示される名前と、友だちがあなたを見つけるためのIDを決めてください。'),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: '表示名',
              helperText: '手紙の差出人として表示されます',
              errorText: _nameError,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _handleController,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'ID',
              prefixText: '@',
              helperText: '英小文字・数字・_ で3〜15文字。あとから変更できません',
              errorText: _handleError,
            ),
          ),
          const SizedBox(height: 32),
          if (_saving)
            const Center(child: CircularProgressIndicator())
          else
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('この内容ではじめる'),
              ),
            ),
        ],
      ),
    );
  }
}
