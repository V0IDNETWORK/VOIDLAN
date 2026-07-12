# VOID LAN

An offline-first LAN companion app: discover devices on your local
network, transfer files peer-to-peer, and chat — all without an
Internet connection. Built with Flutter, Riverpod, GoRouter, and
Clean Architecture / MVVM. Primary targets are **Windows** and
**Android**; **Linux** is supported as a secondary desktop target.

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
storage, notifications, foreground service for background transfers).

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
* **Voice messages** and **background transfer notifications** have
  their data-layer hooks in place (`MessageType.voice`,
  `local_notifier` dependency) but the recording UI and notification
  wiring are left as the next increment — flagging this rather than
  shipping a stub that silently does nothing.

## Package choices

Every package in `pubspec.yaml` is stable and actively maintained as of
early 2026. `multicast_dns` and `bitsdojo_window` were deliberately
**left out**: real RFC 6762 mDNS advertisement needs a full responder
implementation that `multicast_dns` (a query-only client) doesn't
provide — the custom UDP discovery/responder protocol above already
satisfies "auto-advertise, auto-discover" without a half-fit
dependency. `bitsdojo_window` and `window_manager` both take ownership
of native window chrome and conflict if both are wired up; this
project uses `window_manager` alone.

## License

Provided as-is for the requesting party's own use.
