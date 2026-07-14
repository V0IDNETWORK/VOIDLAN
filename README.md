# VOID LAN
An offline-first LAN companion app: discover devices on your local
network, transfer files peer-to-peer, and chat — all without an
Internet connection. Built with Flutter, Riverpod, GoRouter, and
Clean Architecture / MVVM. Primary targets are **Windows** and
**Android**; **Linux** is supported as a secondary desktop target.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![CI](app_icon.png)](https://github.com/V0IDNETWORK/VOIDLAN)

_Replace `OWNER` in the badge URL above with your GitHub username/org once this is pushed to a repo — it can't resolve to a real workflow run from inside this sandbox._

## Platform support

| Platform | Status | Notes |
|---|---|---|
| Android | Primary target | `minSdk 24`, all runtime permissions declared |
| Windows | Primary target | Needs `flutter create --platforms=windows .` once — see below |
| Linux | Secondary target | Needs `flutter create --platforms=linux .` once — see below |
| Web | Not supported | LAN discovery and raw TCP sockets aren't available in a browser sandbox; this is a platform limitation, not a missing feature |
| iOS/macOS | Not supported | Out of scope per the original brief |

## Screenshots

| LAN Explorer | Messenger | About |
|---|---|---|
| ![explorer](docs/screenshots/explorer.png) | ![messenger](docs/screenshots/messenger.png) | ![about](docs/screenshots/about.png) |

## What's new

### This pass — two confirmed crash fixes + real SQLite persistence

Two bugs from an actual `flutter run -d windows` session are fixed, not just theorized about:

* **Hero tag collision crash** — `LanExplorerScreen` and `MessengerScreen` each have a `FloatingActionButton`, and the `StatefulShellRoute` shell keeps every tab's widget tree alive in an `IndexedStack` simultaneously. Both FABs collided on Flutter's shared default hero tag the moment a route transition tried to animate them. Fixed with explicit, unique `heroTag`s on both.
* **"Bad state: Stream has already been listened to"** — a real bug in `LanDiscoveryService`: `startResponder()` (run once at boot) and `_broadcastHandshake()` (run on every scan) were each calling `.listen()` on the same `RawDatagramSocket`, whose stream is single-subscription. Rebuilt around exactly one persistent listener (`_ensureSocketReady`) that dispatches both "answer someone else's broadcast" and "collect replies to mine."
* **Messages, conversations, and transfer history now persist to a real SQLite database** (`DatabaseService`, via `sqflite`/`sqflite_common_ffi`) instead of one-JSON-file-per-conversation and a single JSON blob for transfers. This replaces read-modify-write-the-whole-file on every message with proper indexed row writes, and conversations (not just their messages) now survive a restart.

**Real caveat, not a hidden gotcha:** `sqflite_common_ffi` needs the native `sqlite3` library loadable on Windows/Linux.
- `flutter run` (debug/profile) on Windows: works as-is — the `sqlite3` package's build hooks bundle `sqlite3.dll` automatically.
- `flutter build windows` (**release**): you must manually copy the current `sqlite3.dll` into the same folder as the built `.exe`, per the `sqflite_common_ffi` docs — this is not something Flutter's build does for you.
- Linux: needs the system `libsqlite3-0` package installed (`sudo apt-get install libsqlite3-0`).
- Android: unaffected — plain `sqflite` uses the platform's bundled SQLite, no extra steps.

### Previous pass — network resilience & file management

* **Network Status screen** (pushed from the LAN Explorer app bar) — real connection type, SSID (where the platform/permissions allow it), local IP, gateway IP, and subnet, plus a "connection quality" indicator derived honestly from actual ping times to discovered peers rather than an invented signal-strength number.
* **Manual "Connect by IP"** — a FAB on LAN Explorer for networks where broadcast/multicast discovery is blocked (some mobile hotspots): reuses the exact same TCP-probe logic as the subnet sweep, just against one address the user typed in.
* **Transfer History** (pushed from LAN Explorer) — completed/failed/cancelled transfers now persist to disk (`TransferHistoryService`) and survive an app restart, with search, section grouping (current/completed/failed), and an "open containing folder" (desktop) / "share file" (Android) action per completed transfer.

Explicitly deferred this round, and why — each needs either a dependency with an API not confident enough to write blind, or conflicts with an earlier explicit constraint:

* **QR pairing** — needs a QR-generation package (e.g. `qr_flutter`) and a camera-based scanner (e.g. `mobile_scanner`), neither currently in this project. Mechanically it would generate a QR encoding this device's IP + a pairing nonce and feed a scanned code into the existing `PairingService.requestPairing` flow — the pairing protocol underneath doesn't need to change, only the code that gets the peer's address into it.
* **Windows system tray / minimize-to-tray / start-with-Windows** — a tray icon on Windows needs an actual `.ico` **file**, not a widget-drawn icon; every Flutter tray package (e.g. `tray_manager`) takes a file path. That's a direct conflict with this project's "no assets/ directory" constraint from an earlier round. It's resolvable (either accept one small bundled `.ico`, or generate one at first launch from a rendered widget and cache it), but it's a deliberate trade-off, not something to silently work around.
* **Android background transfers surviving the app being fully killed** — needs a foreground service (e.g. via `flutter_foreground_task`) wrapping the transfer socket loop. The manifest already declares `FOREGROUND_SERVICE_DATA_SYNC` for this; the service itself isn't wired up.
* **Signal strength (RSSI) and raw link speed** on the Network Status screen — not available through `network_info_plus`/`connectivity_plus` on any of this project's target platforms; would need a platform channel per OS. Shown as "unavailable" in the UI rather than a fabricated number.
* **Battery-optimization exemption prompts** on Android — mechanically straightforward (`permission_handler`'s `Permission.ignoreBatteryOptimizations`) but only meaningfully useful once the foreground service above exists.

### Previous pass — UI polish & GitHub readiness

* **Settings screen** (`/settings`, pushed from the LAN Explorer app bar) — theme selection (system/light/dark) and build info. Kept out of the tab bar since the original spec fixes the app at exactly three tabs.
* **Glassmorphism app bars** (`GlassAppBar`) — a `BackdropFilter` blur + gradient tint, built from stock Flutter widgets, applied to every screen. No image assets anywhere in the project; every visual is Material icons, gradients, or `CustomPainter`.
* **Radar-sweep scan animation** (`RadarSweep`, `CustomPainter`) replaces the plain spinner in LAN Explorer's empty/scanning state.
* **Voice messages** got pause/cancel and a real waveform: `VoiceRecorderService` exposes `pause()`/`resume()`/`amplitudeStream()`; `RecordingIndicator` renders the live input level while recording; `VoiceMessageContent` renders a seeded per-message waveform during playback with a progress sweep synced to `audioplayers`' position/duration streams.
* **Entrance animations** (`flutter_animate`, actually wired up — previously declared but unused) on device tiles, conversation tiles, message bubbles, and About links.
* Removed the unused `assets/` folder and `cupertino_icons` dependency — nothing in the app depends on bundled image assets or iOS-style icons.

## Testing

```bash
flutter test
```

Covers pure-logic pieces with no native I/O, so they run the same in
CI as on your machine:

* `test/core/utils/network_utils_test.dart` — subnet math (`hostsInSubnet`): standard /24, small /30, oversized-range and malformed-mask fallback.
* `test/data/services/tcp_framing_test.dart` — the length-prefixed framing protocol: round-trip, one-byte-at-a-time fragmentation, coalesced frames, and the oversized-frame rejection path.
* `test/data/models/transfer_task_model_test.dart` — progress/ETA math.
* `test/data/models/chat_message_model_test.dart` — the chat wire format's `toJson`/`fromJson`.
* `test/widget/device_tile_test.dart` — `DeviceTile` renders the right name/IP/status and responds to taps.

**Honestly out of scope for this pass:** integration tests that spin up
two real sockets and talk to each other (`ConnectionManager`,
`FileTransferService`, `PairingService`, `LanDiscoveryService`) —
those need either a real loopback network in the test environment or
a mocked `Socket`/`RawDatagramSocket` layer, and writing believable
fakes for `dart:io` sockets without being able to run them against the
real implementation risks tests that pass for the wrong reasons. The
pure-logic layer above has real coverage instead of a hollow one.

`.github/workflows/ci.yml` runs `flutter analyze` + `flutter test` on
every push/PR, plus separate debug-build jobs for Android and Windows
(the latter runs `flutter create --platforms=windows .` first, same as
the local setup below, since only a placeholder lives in this repo's
`windows/` folder).

## Getting the project running

The `lib/`, `pubspec.yaml`, and `android/` folders in this project are
complete and hand-written. The `windows/` and `linux/` folders contain
only a `README_FIRST.txt` each, because their CMake/Visual-Studio
runner projects are generated scaffolding tied to your local Flutter
SDK version — they aren't meant to be hand-authored. Generate them
once:

```bash
# From the project root (this folder):
flutter create --platforms=windows,linux .
flutter pub get
```

Then run normally:

```bash
flutter run -d windows   # Windows desktop
flutter run -d linux     # Linux desktop
flutter run -d <deviceid> # Android
```

Android requires `minSdk 24+`; the manifest already declares every
permission the app needs (Wi-Fi state, nearby-device discovery,
storage, microphone, notifications, foreground service for background
transfers).

## Verification status — read this before assuming a clean build

This project was written and reviewed in a sandbox with **no Flutter,
Android, or Windows toolchain and no network access** — there is no
way to actually run `flutter pub get`, `flutter analyze`, `flutter
test`, `flutter build apk`, or `flutter build windows` here, and
claiming those passed without running them would be misleading. What
was done instead, and should be treated as a strong first draft rather
than a guaranteed-clean build:

* Every `package:` import across `lib/` was cross-checked against
  `pubspec.yaml` by hand (no missing or stray dependencies).
* Every route string constructed with `context.go`/`context.push` was
  matched against the corresponding `GoRoute` path in `app_router.dart`.
* Every third-party API call (`record`, `audioplayers`,
  `flutter_local_notifications`, `window_manager`, `desktop_drop`,
  `file_picker`, `device_info_plus`, etc.) was written against the API
  surface of the specific version pinned in `pubspec.yaml`, favoring
  long-stable versions over "latest" where a package has churned its
  API recently (see "Package choices" below).
* One real bug was caught and fixed during review: the original file
  transfer handshake tried to `listen` twice on the same inbound
  socket, which `dart:io` sockets don't allow — it's now a single
  subscription that demultiplexes the header frame from the raw byte
  stream that follows it.

Please run the five commands above yourself after `flutter create`;
if `flutter analyze` surfaces anything, it's most likely a minor typo
or a version-specific API mismatch in one of the third-party plugin
calls, not a structural problem with the architecture.

## Architecture

```
lib/
  core/            constants, theme, router, network utility functions
  data/
    models/        DeviceModel, ChatMessageModel, TransferTaskModel
    services/       all networking: discovery, TCP connections, transfer, chat, pairing
  presentation/
    providers/      Riverpod state notifiers/providers per feature
    shell/          responsive 3-tab shell (NavigationRail on desktop, NavigationBar on mobile)
    lan_explorer/   Tab 1
    about/          Tab 2
    messenger/      Tab 3
```

State flows one way: `services/` own sockets and I/O and expose
streams → `providers/` turn those streams into Riverpod state →
`presentation/` screens are pure functions of that state (MVVM: the
providers are the ViewModels).

## Networking protocol

Everything runs over plain TCP except a single, narrowly-scoped UDP
broadcast used only for presence discovery — chat, pairing, and file
bytes never touch UDP.

| Port | Purpose |
|---|---|
| `58201/tcp` | Control connection: pairing, chat, typing, heartbeat |
| `58202/tcp` | File transfer: one fresh connection per file |
| `58203/udp` | Discovery broadcast/response only |

* **Framing** — every control-port frame is `[4-byte big-endian length][JSON payload]` (`FrameCodec`/`FrameDecoder` in `tcp_framing.dart`), so TCP's fragmentation/coalescing is fully absorbed before the app layer ever sees a message.
* **Heartbeat** — `PeerConnection` sends a heartbeat every 5s and tears the link down if no ack arrives within 15s; `ConnectionManager` then auto-reconnects outbound links every 3s until it succeeds.
* **Discovery** — a UDP broadcast handshake (fast path) plus a concurrent TCP-connect sweep of the local /24 (fallback for networks that block broadcast) run on every scan; see `LanDiscoveryService`.
* **File transfer** — `[JSON header: transferId/fileName/totalBytes][raw bytes from resumeOffset..end]` on its own socket. The receiver writes to a `.part` file and reports its on-disk length as the resume offset, so a retried/interrupted transfer picks up where it left off instead of restarting. See `FileTransferService`.
* **Local server** — `LocalServerService` brings up the control server, transfer server, and discovery responder together at startup so this device is immediately visible to other VOID LAN instances on the LAN.

## Security model — what's implemented and what to add next

* **Pairing** always requires an explicit on-screen confirmation with a
  6-digit verification code the user compares against the peer's
  screen (`PairingService`, `PairingRequestDialog`) before any trust is
  established.
* **File transfers** always require an explicit accept/decline dialog
  before a single byte is written to disk (`IncomingTransferDialog`).
* Once paired, a SHA-256-derived shared secret is stored in
  `flutter_secure_storage` and can be used to authenticate/sign future
  control messages.
* **Honest limitation:** the current build authenticates the control
  channel at the application layer but does not yet encrypt the raw
  socket bytes the way transport-level TLS would. Wiring
  `SecureServerSocket`/`SecureSocket` with a certificate (generated at
  first launch, or provided by the user) is a natural next step for
  full wire encryption; `PeerConnection` and `ConnectionManager` are
  structured so that swap is localized to their socket-creation calls.

## Known scope notes

* **MAC address** resolution shells out to the OS ARP table (`arp -a` /
  `arp -n`) after a successful TCP connect and is best-effort — it
  depends on the OS having already ARPed that host, and is unavailable
  on some locked-down environments (e.g. non-rooted Android).
* **Hostname** is only reliably known for peers running VOID LAN (via
  the discovery/pairing handshake); plain hosts on the network show
  their IP address as the display name since reverse DNS isn't
  reliably available cross-platform without a native dependency.
* **Voice messages** are fully wired: `VoiceRecorderService` records
  AAC audio, sends it through the same confirmation-gated file-transfer
  path as any other attachment, and `VoiceMessageContent` plays it back
  (immediately for the sender via its local temp file, or once the
  receiver has accepted the transfer). Recording is toggle-to-record,
  not press-and-hold — a deliberate simplification that works
  identically on desktop and mobile without gesture-detector edge
  cases.
* **Notifications** are wired cross-platform: `flutter_local_notifications`
  on Android, `local_notifier` on Windows/Linux/macOS, both fired from
  incoming chat messages and completed transfers.
* **Background transfer while the app is fully backgrounded/killed on
  Android** would need a foreground service wrapping the transfer
  socket loop; the manifest already declares the
  `FOREGROUND_SERVICE_DATA_SYNC` permission for this, but the service
  itself isn't wired up yet — flagging this rather than shipping a
  permission that silently does nothing.

## Package choices

Every package in `pubspec.yaml` is stable and actively maintained as of
early 2026. A few deliberate deviations from a literal reading of the
brief, each reasoned through rather than defaulted into:

* **`multicast_dns` and `bitsdojo_window` were left out.** Real RFC
  6762 mDNS advertisement needs a full responder implementation that
  `multicast_dns` (a query-only client) doesn't provide — the custom
  UDP discovery/responder protocol in `LanDiscoveryService` already
  satisfies "auto-advertise, auto-discover" without a half-fit
  dependency. `bitsdojo_window` and `window_manager` both take
  ownership of native window chrome and conflict if both are wired up;
  this project uses `window_manager` alone.
* **`flutter_local_notifications` is pinned to `^17.x`, not latest.**
  The package has moved fast (Windows/Linux toast support, new
  per-platform initialization types); pinning to the 17.x line keeps
  the app on the long-stable core `initialize()`/`show()` surface used
  here rather than chasing a newer major version's API churn.
* **`record` + `audioplayers`** were added (not in the original
  preferred list) to actually implement voice messages rather than
  leave `MessageType.voice` as dead code — both have had a stable core
  API for a long time.

## Folder structure

```
lib/
  core/
    constants/     app_constants.dart — ports, protocol tokens, timeouts, storage keys
    theme/         app_colors.dart, app_theme.dart — Material 3 light/dark cyber theme
    router/        app_router.dart — GoRouter config, AppRoutes constants
    utils/         network_utils.dart — subnet math, local IP resolution
  data/
    models/        DeviceModel, ChatMessageModel, ConversationModel, TransferTaskModel
    services/      every stateful I/O concern — sockets, discovery, transfer, chat,
                   pairing, notifications, voice recording — one responsibility each
  presentation/
    providers/     Riverpod glue between services/ and the UI (the "ViewModel" layer)
    shell/         MainShell — responsive 3-tab NavigationRail/NavigationBar shell
    shared/        cross-feature widgets (currently: GlassAppBar)
    lan_explorer/  Tab 1 + its widgets/ (device tile, details, dialogs, radar sweep)
    about/         Tab 2 + its widgets/ (link card)
    messenger/     Tab 3 + its widgets/ (bubbles, composer, waveform, recording)
    settings/      Settings screen (pushed, not a tab)
android/           Complete, hand-written Gradle/manifest/Kotlin
windows/, linux/   README_FIRST.txt only — run `flutter create` to generate these
```

## Accessibility

- All interactive icons (`IconButton`, tiles) use Material's default
  48dp minimum touch target and carry a `tooltip` where they aren't
  self-explanatory from an adjacent label, which doubles as the
  screen-reader announcement.
- Text styles come from the `Theme`'s `TextTheme` rather than
  hardcoded sizes, so they scale with the system's text-scale factor
  and respect a user's OS-level "large text" setting.
- Status is never conveyed by color alone: online/offline/pairing on
  a device tile pairs a colored dot with an icon and text label; voice
  message playback state pairs an icon change with a text duration.
- Desktop keyboard navigation relies on Flutter's built-in `Focus`
  traversal for `TextField`, buttons, and list items, which comes free
  with Material widgets; no custom focus-trapping was added, since
  none of the custom widgets (`RadarSweep`, `WaveformBars`) are
  interactive — they're decorative/read-only, so they're marked
  `ExcludeSemantics` rather than given fake focus stops.
- **Not yet done:** a full manual screen-reader pass (TalkBack/NVDA)
  wasn't possible in this sandbox — there's no accessibility service
  to attach to in a headless container. Treat the above as
  code-level accessibility hygiene, not a substitute for a real
  screen-reader test pass before shipping.

## License

[MIT](LICENSE).

See [CONTRIBUTING.md](CONTRIBUTING.md) for the development workflow and
[CHANGELOG.md](CHANGELOG.md) for release history.
