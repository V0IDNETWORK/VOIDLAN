import 'dart:io';

import 'package:local_notifier/local_notifier.dart';

/// Thin wrapper around `local_notifier` for desktop toast notifications.
///
/// `local_notifier` only supports Windows/macOS/Linux; on Android the
/// OS-level notification channel is a separate, larger integration
/// (`flutter_local_notifications` + a foreground service for background
/// transfers) that is intentionally out of scope for this pass rather
/// than being stubbed out silently — see the README's "Known scope
/// notes" section.
class NotificationService {
  bool _initialized = false;

  bool get _supported => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> _ensureInitialized() async {
    if (_initialized || !_supported) return;
    await localNotifier.setup(appName: 'VOID LAN');
    _initialized = true;
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String preview,
  }) async {
    if (!_supported) return;
    await _ensureInitialized();
    final notification = LocalNotification(
      title: senderName,
      body: preview,
    );
    await notification.show();
  }

  Future<void> showTransferCompleteNotification({
    required String fileName,
    required bool incoming,
  }) async {
    if (!_supported) return;
    await _ensureInitialized();
    final notification = LocalNotification(
      title: incoming ? 'File received' : 'File sent',
      body: fileName,
    );
    await notification.show();
  }
}
