import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/post_slot_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  /// Last checked location, used to show how far each post is. Only ever
  /// set by an explicit tap — Incomodo doesn't track you in the background.
  ({double latitude, double longitude})? _here;

  String get _uid => ref.read(authStateProvider).value!.uid;

  Future<void> _run(String successMessage, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      _showMessage(successMessage);
    } catch (e) {
      debugPrint('HomeScreen action failed: $e');
      _showMessage('失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveAtCurrentLocation(PostSlot slot, String name) async {
    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    await ref.read(postServiceProvider).savePost(
          uid: _uid,
          slot: slot,
          name: name,
          latitude: position.latitude,
          longitude: position.longitude,
        );
  }

  Future<void> _checkHere() async {
    await _run('現在地を確認しました', () async {
      final position =
          await ref.read(locationServiceProvider).getCurrentPosition();
      if (!mounted) return;
      setState(() => _here =
          (latitude: position.latitude, longitude: position.longitude));
    });
  }

  Future<void> _register(PostSlot slot) async {
    final name = await _askName(title: '${slot.label}を登録', initial: slot.label);
    if (name == null) return;
    await _run('「$name」を登録しました。48時間後に稼働します',
        () => _saveAtCurrentLocation(slot, name));
  }

  Future<void> _rename(Post post) async {
    final name = await _askName(title: '名前を変更', initial: post.name);
    if (name == null) return;
    await _run(
      '名前を変更しました',
      () => ref.read(postServiceProvider).savePost(
            uid: _uid,
            slot: post.slot,
            name: name,
            latitude: post.latitude,
            longitude: post.longitude,
          ),
    );
  }

  Future<void> _move(Post post) async {
    final ok = await _confirm(
      title: '現在地へ移設しますか？',
      message: '「${post.name}」を現在地へ移設します。工事期間（48時間）は最初からやり直しになります。',
      confirmLabel: '移設する',
    );
    if (!ok) return;
    await _run('移設しました。48時間後に稼働します',
        () => _saveAtCurrentLocation(post.slot, post.name));
  }

  Future<void> _delete(Post post) async {
    final ok = await _confirm(
      title: '削除しますか？',
      message: '「${post.name}」を削除します。再登録すると工事期間（48時間）がかかります。',
      confirmLabel: '削除する',
    );
    if (!ok) return;
    await _run(
      '削除しました',
      () => ref.read(postServiceProvider).deletePost(uid: _uid, slot: post.slot),
    );
  }

  Future<String?> _askName({required String title, required String initial}) {
    final controller = TextEditingController(text: initial);
    String? error;
    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(labelText: 'ポストの名前', errorText: error),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () {
                // Coordinates are checked on save; only the name matters here.
                final message = Post.validate(
                    name: controller.text, latitude: 0, longitude: 0);
                if (message != null) {
                  setDialogState(() => error = message);
                  return;
                }
                Navigator.pop(context, controller.text.trim());
              },
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final posts = ref.watch(postsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incomodo'),
        actions: [
          IconButton(
            tooltip: 'ログアウト',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      body: posts.when(
        data: (posts) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ようこそ、${user?.displayName ?? 'ゲスト'}さん',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('手紙の受け取り場所（ポスト）を最大4箇所まで登録できます。'
                '登録・移設から48時間は工事中で、手紙を受け取れません。'
                '手紙はポストから50m以内でしか開けません。'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _checkHere,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(_here == null ? 'ポストに着いたか確認' : '現在地を確認し直す'),
              ),
            ),
            const SizedBox(height: 8),
            for (final slot in PostSlot.values)
              PostSlotCard(
                slot: slot,
                post: posts[slot],
                now: now,
                busy: _busy,
                distanceMeters: _here == null || posts[slot] == null
                    ? null
                    : posts[slot]!
                        .distanceFrom(_here!.latitude, _here!.longitude),
                onRegister: () => _register(slot),
                onRename: () => _rename(posts[slot]!),
                onMove: () => _move(posts[slot]!),
                onDelete: () => _delete(posts[slot]!),
              ),
            if (_busy) ...[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('読み込みに失敗しました: $error')),
      ),
    );
  }
}
