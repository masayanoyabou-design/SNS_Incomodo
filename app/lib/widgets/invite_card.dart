import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/invite.dart';
import '../models/user_profile.dart';

/// Your own invite: the QR to show someone standing in front of you, and
/// the link to send someone who isn't.
class InviteCard extends StatelessWidget {
  const InviteCard({
    super.key,
    required this.profile,
    this.onCopyLink,
    this.qrSize = 180,
  });

  final UserProfile profile;
  final VoidCallback? onCopyLink;
  final double qrSize;

  /// What the QR encodes and what the copy button hands out.
  String get link => Invite.linkFor(profile.handle);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('あなたの招待コード', style: text.titleMedium),
            const SizedBox(height: 12),
            // White background regardless of theme: scanners need the contrast.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: link,
                size: qrSize,
                backgroundColor: Colors.white,
                semanticsLabel: '${profile.handleWithAt} の招待QRコード',
              ),
            ),
            const SizedBox(height: 12),
            Text(profile.displayName, style: text.titleSmall),
            SelectableText(profile.handleWithAt, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              'このQRを読み取ってもらうか、招待リンクを送ると、相手があなたを見つけられます。',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCopyLink,
              icon: const Icon(Icons.link, size: 18),
              label: const Text('招待リンクをコピー'),
            ),
          ],
        ),
      ),
    );
  }
}
