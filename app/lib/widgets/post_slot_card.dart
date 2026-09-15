import 'package:flutter/material.dart';

import '../models/post.dart';

/// One of the four post slots: either a registered post or an empty slot.
class PostSlotCard extends StatelessWidget {
  const PostSlotCard({
    super.key,
    required this.slot,
    required this.post,
    required this.now,
    required this.busy,
    required this.onRegister,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  final PostSlot slot;
  final Post? post;
  final DateTime now;
  final bool busy;
  final VoidCallback onRegister;
  final VoidCallback onRename;
  final VoidCallback onMove;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final post = this.post;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: post == null ? _buildEmpty(context) : _buildPost(context, post),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('${slot.label}（未登録）',
              style: TextStyle(color: Theme.of(context).disabledColor)),
        ),
        FilledButton.tonal(
          onPressed: busy ? null : onRegister,
          child: const Text('現在地で登録'),
        ),
      ],
    );
  }

  Widget _buildPost(BuildContext context, Post post) {
    final active = post.isActive(now);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(slot.label, style: Theme.of(context).textTheme.labelSmall),
              Text(post.name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                active
                    ? '稼働中'
                    : '工事中（あと${_formatRemaining(post.remainingConstruction(now))}）',
                style: TextStyle(
                  color: active ? Colors.green.shade700 : Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
        PopupMenuButton<VoidCallback>(
          enabled: !busy,
          onSelected: (action) => action(),
          itemBuilder: (_) => [
            PopupMenuItem(value: onRename, child: const Text('名前を変更')),
            PopupMenuItem(value: onMove, child: const Text('現在地へ移設')),
            PopupMenuItem(value: onDelete, child: const Text('削除')),
          ],
        ),
      ],
    );
  }

  static String _formatRemaining(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '$hours時間$minutes分' : '$minutes分';
  }
}
