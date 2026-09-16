import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/report.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/safety_provider.dart';
import '../services/slow_response.dart';

/// The ⋮ menu offering to report or block someone (B33), for anywhere a
/// person appears: a letter from them, a friend, a request.
class SafetyMenu extends ConsumerWidget {
  const SafetyMenu({super.key, required this.target, this.letterId, this.onBlocked});

  final UserProfile target;

  /// The letter being reported, when reporting from one.
  final String? letterId;

  /// Called once the block has been handed over, e.g. to leave the screen.
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<_Action>(
      tooltip: '通報・ブロック',
      onSelected: (action) => switch (action) {
        _Action.report => reportPerson(context, ref,
            target: target, letterId: letterId),
        _Action.block => blockPerson(context, ref,
            target: target, onBlocked: onBlocked),
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: _Action.report, child: Text('通報する')),
        PopupMenuItem(value: _Action.block, child: Text('ブロックする')),
      ],
    );
  }
}

enum _Action { report, block }

void _say(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Asks what is wrong and files the report.
Future<void> reportPerson(
  BuildContext context,
  WidgetRef ref, {
  required UserProfile target,
  String? letterId,
}) async {
  final result = await showDialog<(ReportReason, String)>(
    context: context,
    builder: (_) => _ReportDialog(target: target),
  );
  if (result == null || !context.mounted) return;

  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  try {
    await ref.read(safetyServiceProvider).report(
          reporterUid: uid,
          targetUid: target.uid,
          reason: result.$1,
          detail: result.$2,
          letterId: letterId,
        );
    if (!context.mounted) return;
    _say(context, '通報を受け付けました。内容を確認します。相手からの手紙を止めたいときは、ブロックもできます');
  } on SlowResponseException catch (e) {
    if (context.mounted) _say(context, e.message);
  } catch (e) {
    debugPrint('Reporting failed: $e');
    if (context.mounted) _say(context, '通報を送れませんでした: $e');
  }
}

/// Confirms, then blocks.
Future<void> blockPerson(
  BuildContext context,
  WidgetRef ref, {
  required UserProfile target,
  VoidCallback? onBlocked,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${target.displayName}さんをブロックしますか？'),
      content: const Text('友だちから外れ、この人からの手紙と友だちリクエストは届かなくなります。'
          '相手に通知はされません。すでに届いている手紙は、そのまま残ります。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('やめる'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error),
          child: const Text('ブロックする'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  final uid = ref.read(authStateProvider).value?.uid;
  if (uid == null) return;
  try {
    await ref.read(safetyServiceProvider).block(uid: uid, target: target);
    if (context.mounted) _say(context, '${target.displayName}さんをブロックしました');
    onBlocked?.call();
  } on StillSendingException catch (e) {
    if (context.mounted) _say(context, e.message);
    onBlocked?.call();
  } catch (e) {
    debugPrint('Blocking failed: $e');
    if (context.mounted) _say(context, 'ブロックできませんでした: $e');
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.target});

  final UserProfile target;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  ReportReason? _reason;
  final _detail = TextEditingController();

  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.target.displayName}さんを通報'),
      content: SingleChildScrollView(
        child: RadioGroup<ReportReason>(
          groupValue: _reason,
          onChanged: (reason) => setState(() => _reason = reason),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('理由を選んでください。通報したことは相手に知らされません。'),
              const SizedBox(height: 8),
              for (final reason in ReportReason.values)
                RadioListTile<ReportReason>(
                  value: reason,
                  title: Text(reason.label),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              TextField(
                controller: _detail,
                maxLines: 3,
                maxLength: maxReportDetailLength,
                decoration: const InputDecoration(labelText: 'くわしく（任意）'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('やめる'),
        ),
        TextButton(
          onPressed: _reason == null
              ? null
              : () => Navigator.of(context).pop((_reason!, _detail.text)),
          child: const Text('通報する'),
        ),
      ],
    );
  }
}
