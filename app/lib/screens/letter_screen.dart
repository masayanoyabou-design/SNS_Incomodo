import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/letter_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/letter_card.dart';

/// One letter. A received letter stays sealed — its text isn't even on
/// the phone — until you are standing at one of your finished posts.
class LetterScreen extends ConsumerStatefulWidget {
  const LetterScreen({super.key, required this.letter});

  final Letter letter;

  @override
  ConsumerState<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends ConsumerState<LetterScreen> {
  late Letter _letter = widget.letter;
  String? _body;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _body = _letter.body;
    if (_body == null && _letter.isOpened) _loadBody();
  }

  String get _uid => ref.read(authStateProvider).value!.uid;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      debugPrint('LetterScreen action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadBody() => _run(() async {
        final body = await ref
            .read(letterServiceProvider)
            .readBody(uid: _uid, letterId: _letter.id);
        if (mounted) setState(() => _body = body);
      });

  Future<void> _open(Post at) => _run(() async {
        await ref
            .read(letterServiceProvider)
            .open(uid: _uid, letter: _letter);
        if (!mounted) return;
        setState(() => _letter = Letter(
              id: _letter.id,
              direction: _letter.direction,
              counterpartUid: _letter.counterpartUid,
              counterpartDisplayName: _letter.counterpartDisplayName,
              counterpartHandle: _letter.counterpartHandle,
              sentAt: _letter.sentAt,
              openedAt: DateTime.now(),
            ));
        final body = await ref
            .read(letterServiceProvider)
            .readBody(uid: _uid, letterId: _letter.id);
        if (mounted) setState(() => _body = body);
      });

  @override
  Widget build(BuildContext context) {
    final sealed =
        _letter.direction == LetterDirection.received && !_letter.isOpened;
    final here = ref.watch(hereProvider);
    final posts = ref.watch(postsProvider).value ?? const <PostSlot, Post>{};
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final at = here == null
        ? null
        : openablePost(
            posts: posts.values,
            now: now,
            latitude: here.latitude,
            longitude: here.longitude,
          );

    return Scaffold(
      appBar: AppBar(title: Text(sealed ? '届いた手紙' : '手紙')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _letter.direction == LetterDirection.received
                ? '${_letter.counterpartDisplayName}さん（${_letter.counterpartHandleWithAt}）から'
                : '${_letter.counterpartDisplayName}さん（${_letter.counterpartHandleWithAt}）へ',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text('${formatStamp(_letter.sentAt)}・${_letter.statusLabel}'),
          if (_letter.openedAt != null)
            Text('消印：${formatStamp(_letter.openedAt!)}'),
          const SizedBox(height: 24),
          if (sealed)
            _sealed(context, at)
          else
            _paper(context)
          ,
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _sealed(BuildContext context, Post? at) {
    return Column(
      children: [
        Icon(Icons.mail_outline,
            size: 72, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 16),
        Text(
          at != null
              ? '「${at.name}」に着いています。ここで開けます。'
              : ref.watch(hereProvider) == null
                  ? 'この手紙は、あなたのポストの前でしか開けません。'
                  : 'まだポストの近くではありません。ポストまで行くと開けられます。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (at != null)
          FilledButton.icon(
            onPressed: _busy ? null : () => _open(at),
            icon: const Icon(Icons.drafts_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('ここで開ける'),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _busy
                ? null
                : () => _run(() => ref.read(hereProvider.notifier).check()),
            icon: const Icon(Icons.my_location, size: 18),
            label: const Text('現在地を確認する'),
          ),
      ],
    );
  }

  Widget _paper(BuildContext context) {
    if (_body == null && !_busy) {
      return const Text('本文を読み込めませんでした。通信状況を確かめて、開き直してください。');
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SelectableText(
        _body ?? '',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.9),
      ),
    );
  }
}
