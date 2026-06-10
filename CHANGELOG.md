# Changelog — Apex File Share

All notable changes to this project will be documented in this file.

---

## [2.0.4] — 2026-06-08

### Fixed
- **Progress bar appearing on all devices:** `ConnectionWidget.initState()` was setting all devices to `sending` state on rebuild because it only checked `isSending` without identifying the target device; now validates `targetDeviceId == device.id` before restoring state
- **All devices show sending state after tab switch:** same root cause — on list rebuild every `ConnectionWidget` read `isSending=true` and set itself as sending; now only the device matching `targetDeviceId` restores the sending state
- **Receiver shown as sender:** `isGloballyBusy` was passed as `true` to all devices including the target device itself; now `isGloballyBusy=false` for the target device and `true` for all others
- **Progress bar missing on sender device card:** `isGloballyBusy` was hiding the progress bar on the correct device and showing `_buildBusyBar` instead
- **Same issues on TV UI:** `TVSendTab._buildDeviceList()` was passing `isGloballyBusy=true` to all devices without distinction; fixed with the same `targetDeviceId` logic

### Added
- **`TransferProgressService.targetDeviceId`** — identifier of the target device, set in `startBatch()` and cleared in `clearProgress()`; used by `ConnectionWidget` to distinguish the target device from others
- **`TransferProgressService.senderDeviceName`** — name of the sending device, set when a receive begins via HTTP or Nearby
- **`TransferProgressService.startReceive({senderDeviceName})`** — new method to explicitly initialize receive state with the sender device name
- **Sender name in My Device tab:** the receiving progress bar now shows "From: [device name]" below the "Receiving" title
- **Sender name in floating overlay:** shows `← [device name]` below the file name in the floating progress card
- **Android Share Sheet integration:** the app now appears in the Android share menu for all file types; sharing one or multiple files opens Apex Transfer directly and prompts the user to select a device; files are copied from `content://` URIs to a temporary cache directory before sending
- **Theme default changed to System:** the color/theme bottom sheet in Settings now lists System first, matching the Language picker order

### Changed
- `startBatch(int total)` → `startBatch(int total, {String? targetDeviceId})` — now optionally accepts the target device ID
- `http_transfer.sendFiles()` passes `target.id` to `startBatch`
- `nearby_transfer.sendFile()` and `sendBatchFiles()` pass `target.id` to `startBatch`
- `http_transfer.handleUpload()` now calls `startReceive()` instead of leaving receive state uninitialized
- `nearby_transfer.onPayloadReceived()` calls `startReceive(senderDeviceName: device.name)` when a file receive begins

---

## [2.0.3] — 2026-06-08

### Fixed
- **Nearby receive — files not arriving (race condition):** `file_name` bytes message could arrive after the FILE payload, causing the file to be saved as `file_<payloadId>` and the rename to fail silently; receiver now uses dual pending maps to handle both arrival orders
- **Nearby receive — no progress bar on receiver:** `_transferCallbacks` was ignoring all intermediate transfer updates; now calls `updateProgress()` on every byte-count event; sender also includes `size` in `file_name` message for accurate progress
- **Sender shows two progress bars:** `TransferProgressOverlay` was appearing on the sender alongside the inline bar; overlay now hides itself when `isSending` is true
- **Overlay icon wrong for receiver:** changed from `upload_rounded` to `download_rounded` since overlay is now receiver-only
- **Progress bar disappears when switching tabs:** `ConnectionWidget.initState()` now restores `_Status.sending` if a transfer is in progress when the widget rebuilds
- **Receive tab showing sender progress:** `receive_tab` now checks `!isSending` before showing the receiving state
- **Overlay covering bottom navigation bar:** `Positioned.bottom` now uses `MediaQuery.padding.bottom + kBottomNavigationBarHeight + 8` instead of a fixed value
- **Send/receive/files list cut off by navbar:** all three tabs now compute bottom padding dynamically from `MediaQuery.padding.bottom + kBottomNavigationBarHeight + 16`
- **Cancel button not working (sender):** replaced `req.addStream()` with a manual chunk-by-chunk loop (256 KB per chunk) so `isCancelled` is checked before every chunk
- **Cancel button not working (receiver):** reverted to `IOSink` with a single end-of-stream `flush()` — the `RandomAccessFile` busy-loop was consuming CPU and preventing the cancel check from firing
- **Low speed on old devices (40–80 KB/s via WiFi):** removed the periodic `flush()` every 4 MB that was blocking the TCP receive window on slow eMMC storage; now flushes once after the full stream completes

### Added
- `TransferProgressService.isSending` flag — set by `startBatch()`, cleared by `clearProgress()`; used by overlay and receive tab to distinguish sender from receiver
- Sender now includes `size` in `file_name` bytes message so receiver can show accurate progress immediately
- `ConnectionWidget.isGloballyBusy` parameter — disables all send buttons and shows "transfer in progress" bar during active transfers; prevents concurrent send from corrupting shared progress state
- **In-App Update (Android):** added `in_app_update ^4.2.3`; `UpdateService` singleton manages full Flexible update lifecycle with `isBusy` guard — update download happens in background, install is deferred until no active transfer; `WidgetsBindingObserver` handles safe resume from background
- **Tab rename:** "استقبال / Receive" → **"جهازي / My Device"** with `smartphone_rounded` icon across all navigation surfaces (BottomNav, NavigationRail, Sidebar, TV, tab header)
- **AAB size reduction:** excluded `x86_64` ABI (emulator-only) saving ~17 MB; compressed `ico.png` 717 KB→223 KB and `tv-banner.png` 910 KB→471 KB; removed empty Cairo font declarations

---

## [2.0.2] — 2026-06-08

### Fixed
- **Multi-file transfer (Nearby):** receiver was shown an approval dialog per file; now a single batch request is sent with all file names, sizes, and total size — one approval covers the entire transfer
- **Nearby receive — files not arriving (race condition):** `file_name` bytes message could arrive after the FILE payload, causing the file to be saved as `file_<payloadId>` and the rename to fail silently; receiver now uses dual pending maps to handle both arrival orders
- **Nearby receive — no progress bar:** receiver-side `_transferCallbacks` was ignoring all intermediate transfer updates; it now calls `updateProgress()` on every byte-count update so the overlay appears on the receiver
- **Nearby disconnect during transfer:** `onDisconnected` now immediately completes any pending request/connection completers with `false` instead of waiting for the full timeout
- **`stop()` during active transfer:** transfer is now cancelled gracefully before stopping the system (avoids abrupt endpoint termination mid-stream)
- **Device list flicker during batch transfers:** `isTransferring` now also returns `true` while `_isBatchActive` is set, covering the gaps between files in a batch — prevents device list updates or cleanup from firing mid-batch
- **Sender shows two progress bars:** the floating `TransferProgressOverlay` was appearing on the sender alongside the inline bar in `connection_widget`; overlay now hides itself when `isSending` is true and only appears on the receiver
- **Overlay icon wrong for receiver:** icon changed from `upload_rounded` to `download_rounded` since overlay is now receiver-only
- **Low transfer speed on old devices (40–80 KB/s):** the receive path was blocking the TCP socket while flushing to disk every 4 MB; on slow eMMC storage this caused the TCP receive window to fill up, signalling the sender to stall; replaced `IOSink` + periodic `flush()` with a decoupled write loop using `RandomAccessFile.writeFrom()` — socket read loop feeds chunks into a queue at full speed while a background write loop drains to disk independently
- **Files tab not refreshing after receiving:** tab now auto-refreshes via `refreshNotifier` when a new file is received
- **File listing reliability:** `getReceivedFiles` now validates each file individually (`followLinks: false`, per-file stat check) and sort is guarded against `statSync` errors
- **Sort case-sensitivity:** file name sort is now case-insensitive
- Progress update interval on receive reduced from 512 KB to 256 KB for smoother progress on slow connections

### Added
- `ConnectionRequest` model now carries `fileCount` and `fileNames` for batch requests
- Approval dialog shows file count, individual file names (up to 5 + overflow count), and total size for multi-file requests
- `NearbyTransfer.sendBatchFiles()` — single-permission batch send for Nearby Connections
- `NearbyTransfer._handleBatchTransferRequest()` — receiver-side handler for batch requests
- `TransferProgressService._isBatchActive` flag for stronger transfer-period protection
- `TransferProgressService.isSending` flag — distinguishes sender from receiver for overlay visibility
- Sender includes `size` field in `file_name` bytes message so receiver can display accurate progress
- Single-file Nearby send (`sendFile`) now calls `startBatch(1)` for consistent protection

### Changed
- `handleUpload` now uses `RandomAccessFile` instead of `IOSink` for lower-level, non-blocking disk writes

---

## [2.0.1] — 2026-06-07

### Fixed
- Windows device discovery: improved UDP broadcast and IP detection
- File open on Android via FileProvider (works on all file types)
- Sort chip contrast in files tab (text now visible in all themes)
- Bottom sheet SafeArea on files tab

### Added
- Network mode selector (WiFi / LAN) in desktop sidebar — Windows & Linux only
- Window position and size persistence on Windows (saved to registry)
- QR code for Android download shown on Windows/Linux about screen
- PC download banner shown on Android receive tab
- Desktop notifications on Windows/Linux (file received, sent, failed)
- Multi-file transfer: progress shows file x/y with dual progress bars
- TV UI redesigned to match desktop style
- Device list freezes during active transfer (no interruptions)
- `build_windows.bat` + Inno Setup script for Windows installer

### Changed
- App name updated to "Apex File Share" across all platforms
- App icon updated on Windows
- Package name changed to `apex_file_share`
- Removed unused files: `dialog_service`, `preferences_service`, `snackbar_helper`, `support_screen`

---

## [2.0.0] — 2026-04-01

### Added
- Complete redesign of the UI with dark/light mode
- Android TV support with remote control navigation
- Nearby Connections (Android phone ↔ phone)
- UDP broadcast discovery (Desktop ↔ Android)
- HTTP file transfer engine
- Arabic/English with RTL support
- Files tab with categories and sort options
- APK sharing between Android devices

---

## [1.0.0] — 2025-12-01

### Initial release
- Basic WiFi file sharing between Android devices
