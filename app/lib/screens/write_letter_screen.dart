import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../models/stamp_wallet.dart';
import '../models/user_profile.dart';
import '../providers/letter_provider.dart';
import '../providers/stamp_provider.dart';
import '../providers/user_provider.dart';

/// Write to one of your friends. You never choose a post: the letter is
/// addressed to the person, and they read it at whichever of their posts
/// they reach (PRD F-02).
class WriteLetterScreen extends ConsumerStatefulWidget {
  const WriteLetterScreen({super.key, this.to});

  /// Pre-selected recipient, when you came here from a friend.
  final UserProfile? to;

  @override
  ConsumerState<WriteLetterScreen> createState() => _WriteLetterScreenState();
}

class _WriteLetterScreenState extends ConsumerState<WriteLetterScreen> {
  final _bodyController = TextEditingController();
  late UserProfile? _to = widget.to;
  String? _bodyError;
  bool _sending = false;

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final me = ref.read(myProfileProvider).value;
    final to = _to;
    final bodyError = Letter.validateBody(_bodyController.text);
    setState(() => _bodyError = bodyError);
    if (me == null || to == null || bodyError != null) {
      if (to == null) _showMessage('宛先を選んでください');
      return;
    }

    setState(() => _sending = true);
    try {
      await ref.read(letterServiceProvider).sendLetter(
            from: me,
            to: to,
            body: _bodyController.text,
          );
      if (!mounted) return;
      Navigator.pop(context);
      _showMessage('${to.displayName}さんのポストへ送りました');
    } catch (e) {
      debugPrint('Sending a letter failed: $e');
      _showMessage('送れませんでした: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).value ?? const <UserProfile>[];
    final wallet = ref.watch(stampWalletProvider).value;
    final stamps = wallet?.count ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('手紙を書く')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (friends.isEmpty)
            const Text('まだ友だちがいません。先に「友だち」から、IDか招待リンクでつながってください。')
          else ...[
            Row(
              children: [
                const Icon(Icons.local_post_office_outlined, size: 18),
                const SizedBox(width: 6),
                Text('切手 $stamps枚',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              stamps > 0
                  ? '手紙を1通送るごとに切手を1枚使います。毎日${StampWallet.dailyRefill}枚届きます（最大${StampWallet.maxHeld}枚）。'
                  : '切手を切らしています。明日また${StampWallet.dailyRefill}枚届きます。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<UserProfile>(
              initialValue: _to == null
                  ? null
                  : friends.firstWhere((f) => f.uid == _to!.uid,
                      orElse: () => _to!),
              decoration: const InputDecoration(labelText: '宛先'),
              items: [
                for (final friend in friends)
                  DropdownMenuItem(
                    value: friend,
                    child: Text('${friend.displayName}（${friend.handleWithAt}）'),
                  ),
              ],
              onChanged: (value) => setState(() => _to = value),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _bodyController,
              maxLines: 12,
              minLines: 8,
              maxLength: Letter.maxBodyLength,
              decoration: InputDecoration(
                labelText: '本文',
                alignLabelWithHint: true,
                errorText: _bodyError,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            const Text('相手はポストの前に着くまで、この手紙を読めません。'),
            const SizedBox(height: 24),
            if (_sending)
              const Center(child: CircularProgressIndicator())
            else
              FilledButton.icon(
                onPressed: stamps > 0 ? _send : null,
                icon: const Icon(Icons.outgoing_mail),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(stamps > 0 ? '送る' : '切手がありません'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
