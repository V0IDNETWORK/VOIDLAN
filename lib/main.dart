import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';

/// Entry point. Detects the running platform up front and applies the
/// desktop window chrome / mobile runtime permissions each platform
/// needs before the widget tree is built, per the startup requirements:
/// desktop gets an optimized windowed shell, Android gets its runtime
/// permission prompts, and everything else falls through untouched.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (_isDesktop) {
    await _initDesktopWindow();
  } else if (Platform.isAndroid) {
    await _requestAndroidPermissions();
  }

  runApp(const ProviderScope(child: VoidLanApp()));
}

bool get _isDesktop =>
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

Future<void> _initDesktopWindow() async {
  await windowManager.ensureInitialized();
  const options = WindowOptions(
    size: Size(1280, 800),
    minimumSize: Size(960, 640),
    center: true,
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
    title: 'VOID LAN',
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

Future<void> _requestAndroidPermissions() async {
  // // await [
  //   Permission.storage,
  //   Permission.manageExternalStorage,
  //   Permission.nearbyWifiDevices,
  //   Permission.notification,
  // ].request();
  print("hi");
}
