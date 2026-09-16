import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_version.dart';
import '../providers/app_config_provider.dart';

/// Shows [child], unless the server says this build is too old (B31).
///
/// Anything short of a clear answer — still loading, offline, an error —
/// lets the app through: a broken config must never lock everyone out.
class UpdateGate extends ConsumerWidget {
  const UpdateGate({
    super.key,
    required this.child,
    this.currentBuild = AppVersion.build,
  });

  final Widget child;

  /// This build's number; overridable for tests.
  final int currentBuild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimum = ref.watch(minimumBuildProvider).value;
    return needsUpdate(current: currentBuild, minimum: minimum)
        ? const UpdateRequiredScreen()
        : child;
  }
}

class UpdateRequiredScreen extends StatelessWidget {
  const UpdateRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.system_update_outlined, size: 48),
                const SizedBox(height: 16),
                Text('アプリを更新してください', style: text.titleLarge),
                const SizedBox(height: 12),
                const Text(
                  'このバージョンのIncomodoは、もう手紙のやりとりができません。'
                  'ストアから最新のバージョンに更新してください。',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
