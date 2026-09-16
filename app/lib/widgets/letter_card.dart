import 'package:flutter/material.dart';

import '../models/letter.dart';

/// "9月16日 15:04" — no intl dependency, and the year only when it isn't
/// this one, because most letters are recent.
String formatStamp(DateTime when, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final time = '${when.hour}:${when.minute.toString().padLeft(2, '0')}';
  final date = '${when.month}月${when.day}日';
  return when.year == today.year
      ? '$date $time'
      : '${when.year}年$date $time';
}

/// One letter in a list: who it is with, when it was sent, and where it
/// stands. The text is never shown here — a received letter is only read
/// after it has been opened at a post.
class LetterCard extends StatelessWidget {
  const LetterCard({
    super.key,
    required this.letter,
    this.openableAtPostName,
    this.waitingAtPostName,
    this.locationKnown = false,
    this.onTap,
  });

  final Letter letter;

  /// The post the reader is standing at, when they can open this letter.
  final String? openableAtPostName;

  /// The post they are standing at that is still under construction.
  final String? waitingAtPostName;

  /// Whether the reader has checked where they are at all.
  final bool locationKnown;

  final VoidCallback? onTap;

  bool get _isSealed =>
      letter.direction == LetterDirection.received && !letter.isOpened;

  String get _title => letter.direction == LetterDirection.received
      ? '${letter.counterpartDisplayName}さんから'
      : '${letter.counterpartDisplayName}さんへ';

  String? get _hint {
    if (!_isSealed) return null;
    if (openableAtPostName != null) {
      return '「$openableAtPostName」に着いています。ここで開けます';
    }
    if (waitingAtPostName != null) {
      return '「$waitingAtPostName」に着いていますが、工事が終わるまで開けません';
    }
    return locationKnown
        ? 'ポストの近くではありません。ポストまで行くと開けられます'
        : '現在地を確認すると、ここで開けるか分かります';
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final canOpenNow = _isSealed && openableAtPostName != null;

    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          // Sealed until the recipient opens it, whichever side you are on.
          letter.isOpened ? Icons.drafts_outlined : Icons.mail_outline,
          color: canOpenNow ? Theme.of(context).colorScheme.primary : null,
        ),
        title: Text(_title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${formatStamp(letter.sentAt)}・${letter.statusLabel}'),
            if (_hint != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _hint!,
                  style: text.bodySmall?.copyWith(
                    color: canOpenNow
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
