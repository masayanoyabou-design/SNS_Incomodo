import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/post.dart';
import '../models/post_map.dart';
import '../providers/post_provider.dart';
import '../widgets/post_map.dart';

/// Where your posts are, and how far their 50 m reaches. Only ever your own
/// posts: nobody else's location is anywhere in the app.
class PostMapScreen extends ConsumerStatefulWidget {
  const PostMapScreen({super.key, this.showTiles = true});

  /// Off in tests (see [PostMap.showTiles]).
  final bool showTiles;

  @override
  ConsumerState<PostMapScreen> createState() => _PostMapScreenState();
}

class _PostMapScreenState extends ConsumerState<PostMapScreen> {
  bool _checking = false;

  Future<void> _checkHere() async {
    setState(() => _checking = true);
    try {
      await ref.read(hereProvider.notifier).check();
    } catch (e) {
      debugPrint('Checking the location failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(postsProvider).value ?? const <PostSlot, Post>{};
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final here = ref.watch(hereProvider);
    final pins = postPins(posts.values, now);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ポストの地図'),
        actions: [
          IconButton(
            tooltip: '現在地を表示',
            icon: const Icon(Icons.my_location),
            onPressed: _checking ? null : _checkHere,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PostMap(
              // Fits the camera again once there is a location to include.
              key: ValueKey(here != null),
              pins: pins,
              here: here,
              showTiles: widget.showTiles,
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: pins.isEmpty
                      ? const Text(
                          'まだポストがありません。ホーム画面の「現在地で登録」から設置できます。')
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (final pin in pins)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '${pin.slot.label}「${pin.name}」・${pin.statusLabel}',
                                  style: text.bodyMedium,
                                ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              '円の中（ポストから${Post.unlockRadiusMeters.round()}m以内）に入ると、手紙を開けられます。',
                              style: text.bodySmall,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
