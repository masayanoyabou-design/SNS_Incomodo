import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/invite.dart';

/// Reads a friend's invite QR code with the camera (B24) and returns the
/// handle in it, or nothing if the screen is closed first.
///
/// Only Incomodo invites count: any other code in view is ignored rather
/// than sending the user off to some link.
class ScanInviteScreen extends StatefulWidget {
  const ScanInviteScreen({super.key});

  @override
  State<ScanInviteScreen> createState() => _ScanInviteScreenState();
}

class _ScanInviteScreenState extends State<ScanInviteScreen> {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _done = false;
  String? _notInvite;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final code in capture.barcodes) {
      final handle = handleFromScan(code.rawValue);
      if (handle != null) {
        _done = true;
        Navigator.of(context).pop(handle);
        return;
      }
    }
    setState(() => _notInvite = 'Incomodoの招待QRコードではないようです');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('招待QRコードを読み取る')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => ColoredBox(
              color: Colors.black,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    error.errorCode == MobileScannerErrorCode.permissionDenied
                        ? 'カメラの使用が許可されていません。端末の設定から許可するか、IDを入力して探してください'
                        : 'カメラを起動できませんでした。IDを入力して探してください',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(20),
              child: Text(
                _notInvite ?? '友だちのアプリの「友だち」画面にあるQRコードを映してください',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The handle in a scanned code, if it is an Incomodo invite, or null.
///
/// Stricter than pasting: a QR code seen through the camera could be any
/// poster's, and [Invite.handleFrom] would read the last part of any link
/// (`https://some.shop/menu` → "menu") as an ID. So a link must be to the
/// invite site, and plain text must be an `@handle`.
String? handleFromScan(String? raw) {
  if (raw == null) return null;
  final text = raw.trim();
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme) {
    return uri.host == Uri.parse(Invite.site).host
        ? Invite.handleFrom(text)
        : null;
  }
  return text.startsWith('@') ? Invite.handleFrom(text) : null;
}
