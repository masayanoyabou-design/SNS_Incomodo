import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/letter_provider.dart';
import '../providers/post_provider.dart';
import '../providers/safety_provider.dart';
import '../providers/stamp_provider.dart';
import '../providers/user_provider.dart';
import '../services/location_service.dart';
import '../services/slow_response.dart';
import '../widgets/post_slot_card.dart';
import 'friends_screen.dart';
import 'letters_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _busy = false;

  String get _uid => ref.read(authStateProvider).value!.uid;

  @override
  void initState() {
    super.initState();
    // Today's stamps, handed out on the first launch of the day. Failing
    // is harmless — the next launch tries again.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(stampServiceProvider).ensureToday(uid: _uid);
      } catch (e) {
        debugPrint('Handing out stamps failed: $e');
      }
    });
  }

  /// Runs [action], then says [successMessage] — or, when that is null, lets
  /// the caller decide what to say from whether it succeeded.
  Future<bool> _run(
      String? successMessage, Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      if (successMessage != null) _showMessage(successMessage);
      return true;
    } catch (e) {
      debugPrint('HomeScreen action failed: $e');
      // These already say what happened and what to do. A slow write in
      // particular may still go through, so "failed" would be wrong.
      _showMessage(e is SlowResponseException || e is LocationException
          ? e.toString()
          : '失敗しました: $e');
      return false;
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

  /// Returns whether it was the account's first post (no construction).
  Future<bool> _saveAtCurrentLocation(PostSlot slot, String name) async {
    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    return ref.read(postServiceProvider).savePost(
          uid: _uid,
          slot: slot,
          name: name,
          latitude: position.latitude,
          longitude: position.longitude,
        );
  }

  Future<void> _checkHere() =>
      _run('現在地を確認しました', ref.read(hereProvider.notifier).check);

  Future<void> _register(PostSlot slot) async {
    final name = await _askName(title: '${slot.label}を登録', initial: slot.label);
    if (name == null) return;
    var first = false;
    final saved = await _run(
        null, () async => first = await _saveAtCurrentLocation(slot, name));
    if (!saved) return;
    _showMessage(first
        ? '「$name」を登録しました。最初のポストなので、すぐに使えます'
        : '「$name」を登録しました。48時間後に稼働します');
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
      message: post.firstPost
          ? '「${post.name}」を現在地へ移設します。移設先は、最初のポストでも48時間の工事が必要です。'
          : '「${post.name}」を現在地へ移設します。工事期間（48時間）は最初からやり直しになります。',
      confirmLabel: '移設する',
    );
    if (!ok) return;
    await _run('移設しました。48時間後に稼働します',
        () => _saveAtCurrentLocation(post.slot, post.name));
  }

  Future<void> _delete(Post post) async {
    final ok = await _confirm(
      title: '削除しますか？',
      message: post.firstPost
          ? '「${post.name}」を削除します。最初のポストの工事なしは1回限りのため、'
              '再登録すると工事期間（48時間）がかかります。'
          : '「${post.name}」を削除します。再登録すると工事期間（48時間）がかかります。',
      confirmLabel: '削除する',
    );
    if (!ok) return;
    await _run(
      '削除しました',
      () => ref.read(postServiceProvider).deletePost(uid: _uid, slot: post.slot),
    );
  }

  /// Deleting the account (B34). Nothing here can be undone, so it says
  /// exactly what goes and what stays before asking.
  Future<void> _deleteAccount() async {
    final profile = ref.read(myProfileProvider).value;
    if (profile == null) return;
    final ok = await _confirm(
      title: 'アカウントを削除しますか？',
      message: 'プロフィール、ID（${profile.handleWithAt}）、ポスト、切手、友だち、'
          '届いた手紙と送った手紙の控えがすべて削除され、元に戻せません。'
          '相手に届けた手紙は、相手の手元に残ります。\n\n'
          '確認のため、次にGoogleでもう一度ログインしてください。',
      confirmLabel: '削除する',
    );
    if (!ok) return;

    setState(() => _busy = true);
    try {
      await ref
          .read(accountServiceProvider)
          .deleteAccount(uid: profile.uid, handle: profile.handle);
      // Signed out now: the app goes back to the sign-in screen by itself.
    } catch (e) {
      debugPrint('Deleting the account failed: $e');
      _showMessage(switch (e) {
        FirebaseAuthException(code: 'user-mismatch') =>
          'ログイン中とは別のGoogleアカウントが選ばれました。削除は行っていません',
        GoogleSignInException(code: GoogleSignInExceptionCode.canceled) =>
          'ログインが取り消されたため、削除は行っていません',
        _ => '削除できませんでした。電波の良い場所で、もう一度お試しください（$e）',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    final profile = ref.watch(myProfileProvider).value;
    final posts = ref.watch(postsProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final here = ref.watch(hereProvider);
    final unopened = ref.watch(unopenedCountProvider);
    final requests = ref.watch(friendRequestsProvider).value?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Incomodo'),
        actions: [
          IconButton(
            tooltip: '手紙',
            // The count is the only hint you get: Incomodo never notifies.
            icon: Badge.count(
              count: unopened,
              isLabelVisible: unopened > 0,
              child: const Icon(Icons.mail_outline),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LettersScreen()),
            ),
          ),
          IconButton(
            tooltip: '友だち',
            // Until you answer a request, you can't write to that person,
            // so it needs to be visible from here.
            icon: Badge.count(
              count: requests,
              isLabelVisible: requests > 0,
              child: const Icon(Icons.people_outline),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const FriendsScreen()),
            ),
          ),
          PopupMenuButton<_AccountAction>(
            tooltip: 'アカウント',
            icon: const Icon(Icons.account_circle_outlined),
            enabled: !_busy,
            onSelected: (action) => switch (action) {
              _AccountAction.signOut =>
                ref.read(authServiceProvider).signOut(),
              _AccountAction.delete => _deleteAccount(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                  value: _AccountAction.signOut, child: Text('ログアウト')),
              PopupMenuItem(
                  value: _AccountAction.delete, child: Text('アカウントを削除')),
            ],
          ),
        ],
      ),
      body: posts.when(
        data: (posts) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('ようこそ、${profile?.displayName ?? 'ゲスト'}さん',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text('手紙の受け取り場所（ポスト）を最大4箇所まで登録できます。'
                '最初に登録するポストはすぐ使えます。2つ目以降と移設したポストは、'
                '48時間の工事が終わるまで手紙を開けません。'
                '手紙はポストから50m以内でしか開けません。'),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _checkHere,
                icon: const Icon(Icons.my_location, size: 18),
                label: Text(here == null ? 'ポストに着いたか確認' : '現在地を確認し直す'),
              ),
            ),
            const SizedBox(height: 8),
            for (final slot in PostSlot.values)
              PostSlotCard(
                slot: slot,
                post: posts[slot],
                now: now,
                busy: _busy,
                distanceMeters: here == null || posts[slot] == null
                    ? null
                    : posts[slot]!
                        .distanceFrom(here.latitude, here.longitude),
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

enum _AccountAction { signOut, delete }
