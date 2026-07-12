/// Static configuration values shared by every networking layer in the app.
///
/// Keeping ports and protocol tokens in one place avoids magic numbers
/// scattered across the discovery, transfer, and messenger services.
class AppConstants {
  const AppConstants._();

  static const String appName = 'VOID LAN';

  // --- Ports -----------------------------------------------------------
  /// TCP port the local control/chat server listens on.
  static const int controlPort = 58201;

  /// TCP port used exclusively for file-transfer streams.
  static const int transferPort = 58202;

  /// UDP port used only for lightweight presence broadcast/discovery.
  /// No chat or file data is ever sent over this socket.
  static const int discoveryPort = 58203;

  /// mDNS service type VOID LAN instances advertise themselves under.
  static const String mdnsServiceType = '_voidlan._tcp';

  // --- Protocol ----------------------------------------------------------
  static const String discoveryMagic = 'VOIDLAN_HELLO';
  static const String discoveryAck = 'VOIDLAN_ACK';

  // --- Timeouts / intervals ----------------------------------------------
  static const Duration scanConnectTimeout = Duration(milliseconds: 350);
  static const Duration heartbeatInterval = Duration(seconds: 5);
  static const Duration heartbeatTimeout = Duration(seconds: 15);
  static const Duration reconnectDelay = Duration(seconds: 3);

  // --- Transfer ------------------------------------------------------------
  static const int chunkSize = 64 * 1024; // 64 KB per frame
  static const int maxFrameLength = 16 * 1024 * 1024; // 16 MB safety cap

  // --- Storage keys --------------------------------------------------------
  static const String secureKeyDeviceId = 'void_lan_device_id';
  static const String secureKeyPairingSecret = 'void_lan_pairing_secret';

  /// Subfolder of the app's documents directory that received files
  /// (including voice messages) are saved into.
  static const String receivedFilesDirName = 'VoidLanReceived';
}
