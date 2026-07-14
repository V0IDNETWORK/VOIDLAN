package ir.voidnetwork.voidlan

import io.flutter.embedding.android.FlutterActivity

/**
 * VOID LAN's single native entry point. All device/network/file-system
 * access is handled through the Flutter plugins declared in
 * pubspec.yaml (network_info_plus, file_picker, permission_handler,
 * etc.) via their own platform channels, so no custom channel wiring is
 * required here.
 */
class MainActivity : FlutterActivity()
