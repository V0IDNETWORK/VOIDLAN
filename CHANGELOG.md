# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed
- Hero tag collision crash between the LAN Explorer and Messenger FloatingActionButtons (unique heroTags).
- "Bad state: Stream has already been listened to" crash in LanDiscoveryService — the UDP discovery socket was being listened to twice; now uses one shared listener.

### Changed
- Messages, conversations, and transfer history now persist to SQLite (`sqflite`/`sqflite_common_ffi`) instead of per-conversation JSON files and a single JSON blob.

### Added
- Unit tests for subnet math, TCP frame codec/decoder, transfer progress/ETA math, and chat message JSON serialization; a widget test for DeviceTile.
- GitHub Actions CI workflow (analyze, test, and debug builds for Android/Windows).
- Network Status screen: connection type, SSID, local/gateway IP, subnet, and a ping-derived connection-quality indicator.
- Manual "Connect by IP" for networks where broadcast/multicast discovery is blocked.
- Persisted Transfer History screen (search, current/completed/failed grouping, open-folder/share actions).
- Initial LAN Explorer: UDP broadcast + TCP-sweep discovery, device details, drag-and-drop/picker file sending.
- Resumable, cancellable, progress-tracked file transfer protocol over a dedicated TCP port.
- Offline messenger: text chat, typing indicators, seen receipts, reply/forward/pin/delete, disk-persisted history.
- Voice messages: record with pause/cancel, live waveform, playback with a synced progress sweep.
- Device pairing with a 6-digit out-of-band verification code before trust is established.
- Cross-platform notifications (`flutter_local_notifications` on Android, `local_notifier` on desktop).
- Settings screen (theme selection) reachable from the LAN Explorer app bar.
- Glassmorphism app bars, radar-sweep scanning animation, and entrance animations across list items.
- About tab with the project's links and contact info.

### Known limitations
- Control-channel messages are authenticated (pairing + shared secret) but not yet wire-encrypted with TLS.
- No Android foreground service yet for transfers continuing while the app is fully backgrounded.
- `windows/` and `linux/` runner projects must be generated locally via `flutter create` — see README.
