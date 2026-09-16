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
    required this.distanceMeters,
    required this.onRegister,
    required this.onRename,
    required this.onMove,
    required this.onDelete,
  });

  final PostSlot slot;
  final Post? post;
  final DateTime now;
  final bool busy;

  /// Distance from the viewer's last known location, or null if unknown.
  final double? distanceMeters;
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
              if (distanceMeters != null) _buildDistance(context, post),
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

  Widget _buildDistance(BuildContext context, Post post) {
    final distance = distanceMeters!;
    final arrived = distance <= Post.unlockRadiusMeters;
    final canOpen = arrived && post.isActive(now);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            arrived ? Icons.where_to_vote : Icons.directions_walk,
            size: 16,
            color: canOpen
                ? Colors.green.shade700
                : Theme.of(context).textTheme.bodySmall?.color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              canOpen
                  ? 'ポストに到着（ここで手紙を開けます）'
                  : arrived
                      ? 'ポストに到着（工事が終わるまで開けません）'
                      : '現在地から約${_formatDistance(distance)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: canOpen ? Colors.green.shade700 : null,
                    fontWeight: canOpen ? FontWeight.bold : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDistance(double meters) => meters < 1000
      ? '${meters.round()}m'
      : '${(meters / 1000).toStringAsFixed(1)}km';

  static String _formatRemaining(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return hours > 0 ? '$hours時間$minutes分' : '$minutes分';
  }
}
