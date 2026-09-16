import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/letter.dart';
import '../providers/letter_provider.dart';
import '../widgets/postmark.dart';
import '../widgets/stamp_view.dart';
import 'letter_screen.dart';

/// The letters you went and got, laid out like a stamp album (B28): each
/// one its stamp, cancelled with the postmark of where and when you opened
/// it.
class AlbumScreen extends ConsumerWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final letters = ref.watch(albumProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('手紙のアルバム')),
      body: letters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('読み込みに失敗しました: $error')),
        data: (letters) => letters.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text(
                    'ポストまで行って開けた手紙が、ここに並んでいきます。',
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 180,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: letters.length,
                itemBuilder: (context, i) => AlbumTile(
                  letter: letters[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LetterScreen(letter: letters[i]),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// One page of the album: the stamp, its postmark, and who it was from.
class AlbumTile extends StatelessWidget {
  const AlbumTile({super.key, required this.letter, this.onTap});

  final Letter letter;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final opened = letter.openedAt!;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 104,
                    height: 100,
                    child: Stack(
                      children: [
                        Positioned(
                          right: 4,
                          top: 4,
                          child: StampView(design: letter.stamp, width: 60),
                        ),
                        Positioned(
                          left: 0,
                          bottom: 0,
                          child: Postmark(
                            date: opened,
                            place: letter.openedPlace,
                            size: 64,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${letter.counterpartDisplayName}さんから',
                style: text.titleSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                [formatPostmarkDate(opened), ?letter.openedPlace].join('・'),
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
