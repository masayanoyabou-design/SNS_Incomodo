import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../providers/user_provider.dart';

/// Find people by ID, answer connection requests, and see who you can
/// exchange letters with.
class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen> {
  final _searchController = TextEditingController();
  UserProfile? _found;
  String? _searchMessage;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('FriendsScreen action failed: $e');
      _showMessage('失敗しました: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _search() async {
    final error = UserProfile.validateHandle(_searchController.text);
    if (error != null) {
      setState(() {
        _found = null;
        _searchMessage = error;
      });
      return;
    }
    await _run(() async {
      final me = ref.read(myProfileProvider).value;
      final found =
          await ref.read(userServiceProvider).findByHandle(_searchController.text);
      if (!mounted) return;
      setState(() {
        _found = found?.uid == me?.uid ? null : found;
        _searchMessage = found == null
            ? 'そのIDのユーザーは見つかりませんでした'
            : found.uid == me?.uid
                ? 'それはあなた自身のIDです'
                : null;
      });
    });
  }

  Future<void> _request(UserProfile target) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    await _run(() async {
      await ref
          .read(userServiceProvider)
          .sendFriendRequest(from: me, targetUid: target.uid);
      _showMessage('${target.displayName}さんにリクエストを送りました');
      if (mounted) setState(() => _found = null);
    });
  }

  Future<void> _accept(UserProfile requester) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    await _run(() async {
      await ref
          .read(userServiceProvider)
          .acceptFriendRequest(me: me, requester: requester);
      _showMessage('${requester.displayName}さんとつながりました');
    });
  }

  Future<void> _decline(UserProfile requester) async {
    final me = ref.read(myProfileProvider).value;
    if (me == null) return;
    await _run(() => ref.read(userServiceProvider).declineFriendRequest(
          uid: me.uid,
          requesterUid: requester.uid,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(myProfileProvider).value;
    final requests = ref.watch(friendRequestsProvider).value ?? const [];
    final friends = ref.watch(friendsProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('友だち')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (me != null) ...[
            Text('あなたのID', style: Theme.of(context).textTheme.labelMedium),
            SelectableText(
              me.handleWithAt,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text('このIDを相手に伝えると、相手から見つけてもらえます'),
            const Divider(height: 32),
          ],
          Text('IDで探す', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: '相手のID',
                    prefixText: '@',
                    errorText: _searchMessage,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : _search,
                child: const Text('探す'),
              ),
            ],
          ),
          if (_found != null)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: ListTile(
                title: Text(_found!.displayName),
                subtitle: Text(_found!.handleWithAt),
                trailing: FilledButton.tonal(
                  onPressed: _busy ? null : () => _request(_found!),
                  child: const Text('リクエスト'),
                ),
              ),
            ),
          const Divider(height: 32),
          Text('届いているリクエスト（${requests.length}）',
              style: Theme.of(context).textTheme.titleMedium),
          if (requests.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('ありません'),
            ),
          for (final requester in requests)
            Card(
              child: ListTile(
                title: Text(requester.displayName),
                subtitle: Text(requester.handleWithAt),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => _decline(requester),
                      child: const Text('断る'),
                    ),
                    FilledButton(
                      onPressed: _busy ? null : () => _accept(requester),
                      child: const Text('つながる'),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 32),
          Text('友だち（${friends.length}）',
              style: Theme.of(context).textTheme.titleMedium),
          if (friends.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('まだいません'),
            ),
          for (final friend in friends)
            Card(
              child: ListTile(
                title: Text(friend.displayName),
                subtitle: Text(friend.handleWithAt),
              ),
            ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
