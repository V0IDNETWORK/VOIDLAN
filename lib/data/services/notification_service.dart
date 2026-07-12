import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_notifier/local_notifier.dart';

/// Cross-platform notification wrapper.
///
/// Two backends are used deliberately rather than one uncertain
/// "does everything" dependency:
///  * **Android** — `flutter_local_notifications`, whose core
///    `initialize()`/`show()` surface has been stable for years; this
///    project pins it to the 17.x line specifically to stay on that
///    well-understood surface rather than chasing newer major versions
///    that also restructured the Windows-specific initialization API
///    this project doesn't need.
///  * **Windows/Linux/macOS** — `local_notifier`, a much smaller,
///    desktop-only package with a single `show()` call and no native
///    channel configuration required.
///
/// Both are initialized lazily on first use so app startup never waits
/// on notification permission plumbing.
class NotificationService {
  static const _androidChannelId = 'void_lan_messages';
  static const _androidChannelName = 'VOID LAN';

  final FlutterLocalNotificationsPlugin _androidPlugin =
      FlutterLocalNotificationsPlugin();
  bool _androidInitialized = false;
  bool _desktopInitialized = false;
  int _notificationId = 0;

  bool get _isAndroid => Platform.isAndroid;
  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  Future<void> _ensureAndroidInitialized() async {
    if (_androidInitialized) return;
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: androidSettings);
    await _androidPlugin.initialize(settings);
    _androidInitialized = true;
  }

  Future<void> _ensureDesktopInitialized() async {
    if (_desktopInitialized) return;
    await localNotifier.setup(appName: 'VOID LAN');
    _desktopInitialized = true;
  }

  Future<void> _show({required String title, required String body}) async {
    if (_isAndroid) {
      await _ensureAndroidInitialized();
      const androidDetails = AndroidNotificationDetails(
        _androidChannelId,
        _androidChannelName,
        channelDescription: 'Incoming messages and file transfers on your LAN',
        importance: Importance.high,
        priority: Priority.high,
      );
      await _androidPlugin.show(
        _notificationId++,
        title,
        body,
        const NotificationDetails(android: androidDetails),
      );
      return;
    }
    if (_isDesktop) {
      await _ensureDesktopInitialized();
      final notification = LocalNotification(title: title, body: body);
      await notification.show();
    }
  }

  Future<void> showMessageNotification({
    required String senderName,
    required String preview,
  }) {
    return _show(title: senderName, body: preview);
  }

  Future<void> showTransferCompleteNotification({
    required String fileName,
    required bool incoming,
  }) {
    return _show(
      title: incoming ? 'File received' : 'File sent',
      body: fileName,
    );
  }
}
