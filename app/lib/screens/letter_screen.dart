import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/letter_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/envelope_view.dart';
import '../widgets/letter_card.dart';
import '../widgets/letter_paper.dart';
import '../widgets/postmark.dart';
import '../widgets/stamp_view.dart';

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

  Future<void> _loadBody() => _run(_fetchContents);

  /// The text and the paper arrive together, and only after opening.
  Future<void> _fetchContents() async {
    final contents = await ref
        .read(letterServiceProvider)
        .readContents(uid: _uid, letterId: _letter.id);
    if (!mounted || contents == null) return;
    setState(() {
      _letter = _letter.withContents(
          body: contents.body, paperId: contents.paperId);
      _body = contents.body;
    });
  }

  Future<void> _open(Post at) => _run(() async {
        await ref
            .read(letterServiceProvider)
            .open(uid: _uid, letter: _letter, place: at.name);
        if (!mounted) return;
        setState(() =>
            _letter = _letter.markOpened(DateTime.now(), place: at.name));
        await _fetchContents();
      });

  /// What throwing this one away costs, said before it happens (B25).
  String _throwAwayWarning(bool sealed) => switch (_letter.direction) {
        LetterDirection.received when sealed =>
          'まだ開けていない手紙です。捨てると、もう読むことはできません。',
        LetterDirection.received => '捨てた手紙は元に戻せません。',
        LetterDirection.sent =>
          'あなたの控えだけが消えます。相手に届いた手紙はそのまま残ります。',
      };

  Future<void> _throwAway(bool sealed) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('この手紙を捨てますか？'),
        content: Text(_throwAwayWarning(sealed)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('やめる'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('捨てる'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    var done = false;
    await _run(() async {
      await ref
          .read(letterServiceProvider)
          .delete(uid: _uid, letter: _letter);
      done = true;
    });
    if (done && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final sealed =
        _letter.direction == LetterDirection.received && !_letter.isOpened;
    final here = ref.watch(hereProvider);
    final posts = ref.watch(postsProvider).value ?? const <PostSlot, Post>{};
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final openable = here == null
        ? null
        : openablePost(
            posts: posts.values,
            now: now,
            latitude: here.latitude,
            longitude: here.longitude,
          );
    final waitingAt = here == null || openable != null
        ? null
        : postYouAreAt(
            posts: posts.values,
            latitude: here.latitude,
            longitude: here.longitude,
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(sealed ? '届いた手紙' : '手紙'),
        actions: [
          IconButton(
            tooltip: '手紙を捨てる',
            icon: const Icon(Icons.delete_outline),
            onPressed: _busy ? null : () => _throwAway(sealed),
          ),
        ],
      ),
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
            Text([
              '消印：${formatStamp(_letter.openedAt!)}',
              ?_letter.openedPlace,
            ].join('・')),
          const SizedBox(height: 24),
          if (sealed)
            _sealed(context, openable, waitingAt, now)
          else
            _paper(context),
          if (_busy) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _sealed(
      BuildContext context, Post? openable, Post? waitingAt, DateTime now) {
    return Column(
      children: [
        EnvelopeView(
          design: _letter.envelope,
          stamp: _letter.stamp,
          from:
              '${_letter.counterpartDisplayName}（${_letter.counterpartHandleWithAt}）',
        ),
        const SizedBox(height: 20),
        Text(
          switch ((openable, waitingAt)) {
            (final Post at, _) => '「${at.name}」に着いています。ここで開けます。',
            (_, final Post at) => '「${at.name}」に着いていますが、まだ工事中です。'
                '${_remaining(at, now)}に開けられるようになります。',
            _ => ref.watch(hereProvider) == null
                ? 'この手紙は、あなたのポストの前でしか開けません。'
                : 'まだポストの近くではありません。ポストまで行くと開けられます。',
          },
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (openable != null)
          FilledButton.icon(
            onPressed: _busy ? null : () => _open(openable),
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

  /// "あと3時間20分" — the same wording the post card uses.
  String _remaining(Post post, DateTime now) {
    final left = post.remainingConstruction(now);
    final hours = left.inHours;
    final minutes = left.inMinutes % 60;
    return hours > 0 ? 'あと$hours時間$minutes分' : 'あと$minutes分';
  }

  Widget _paper(BuildContext context) {
    if (_body == null && !_busy) {
      return const Text('本文を読み込めませんでした。通信状況を確かめて、開き直してください。');
    }
    final opened = _letter.openedAt;
    return LetterPaper(
      body: _body ?? '',
      design: _letter.paper,
      corner: SizedBox(
        width: 120,
        height: 96,
        child: Stack(
          children: [
            Positioned(
              right: 4,
              top: 0,
              child: StampView(design: _letter.stamp, width: 64),
            ),
            // Struck across the stamp's lower-left, the way a postmark
            // lands half on the stamp and half on the paper.
            if (opened != null)
              Positioned(
                left: 0,
                bottom: 0,
                child: Postmark(
                  date: opened,
                  place: _letter.openedPlace,
                  size: 72,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
