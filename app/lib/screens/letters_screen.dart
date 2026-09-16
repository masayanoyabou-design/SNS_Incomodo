import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../models/post.dart';
import '../providers/letter_provider.dart';
import '../providers/post_provider.dart';
import '../widgets/letter_card.dart';
import 'letter_screen.dart';
import 'write_letter_screen.dart';

/// The letters that have arrived, and the ones you have sent.
class LettersScreen extends ConsumerWidget {
  const LettersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('手紙'),
          actions: [
            Builder(
              builder: (context) => IconButton(
                tooltip: here == null ? '現在地を確認' : '現在地を確認し直す',
                icon: const Icon(Icons.my_location),
                onPressed: () async {
                  try {
                    await ref.read(hereProvider.notifier).check();
                  } catch (e) {
                    debugPrint('Checking the location failed: $e');
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(content: Text('失敗しました: $e')));
                  }
                },
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [Tab(text: '届いた手紙'), Tab(text: '送った手紙')],
          ),
        ),
        body: TabBarView(
          children: [
            _LetterList(
              letters: ref.watch(receivedLettersProvider),
              emptyMessage: 'まだ手紙は届いていません。',
              openableAtPostName: at?.name,
              locationKnown: here != null,
            ),
            _LetterList(
              letters: ref.watch(sentLettersProvider),
              emptyMessage: 'まだ手紙を送っていません。',
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WriteLetterScreen()),
          ),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('手紙を書く'),
        ),
      ),
    );
  }
}

class _LetterList extends StatelessWidget {
  const _LetterList({
    required this.letters,
    required this.emptyMessage,
    this.openableAtPostName,
    this.locationKnown = false,
  });

  final AsyncValue<List<Letter>> letters;
  final String emptyMessage;
  final String? openableAtPostName;
  final bool locationKnown;

  @override
  Widget build(BuildContext context) {
    return letters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(child: Text('読み込みに失敗しました: $error')),
      data: (letters) => letters.isEmpty
          ? Center(child: Text(emptyMessage))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                for (final letter in letters)
                  LetterCard(
                    letter: letter,
                    openableAtPostName: openableAtPostName,
                    locationKnown: locationKnown,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LetterScreen(letter: letter),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
