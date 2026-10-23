# Changelog — Apex File Share

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.0.5] — 2026-08-11

### Added
- **Linux clipboard monitoring** — GTK `owner-change` signal in `my_application.cc`
  handles text, images (`image/png`), and files (`text/uri-list`);
  writes temp files to `/tmp/` and notifies Dart via MethodChannel
- Clipboard monitoring now active on **Windows and Linux** (previously Windows-only)

### Fixed
- **Open received file on Windows/Linux/macOS** — replaced unreliable `open_filex`
  with native process calls (`cmd /c start` · `xdg-open` · `open`)
  so the file opens in its associated application instead of silently failing

---

## [2.0.4] — 2026-06-08

### Fixed
- Progress bar appearing on all devices simultaneously during transfer
- All devices showing sending state after tab switch
- Receiver shown as sender in progress UI
- Progress bar missing on correct sender device card
- Same issues replicated in TV UI

### Added
- `TransferProgressService.targetDeviceId` — identifies the target device across widgets
- `TransferProgressService.senderDeviceName` — shown in receiving progress bar
- `TransferProgressService.startReceive()` — explicit receive-state initializer
- Sender name displayed in My Device tab and floating overlay during receive
- **Android Share Sheet integration** — app appears in system share menu for all file types
- Theme default changed to System (matches OS preference on first launch)

### Changed
- `startBatch(int total)` → `startBatch(int total, {String? targetDeviceId})`

---

## [2.0.3] — 2026-06-08

### Fixed
- Nearby receive race condition — `file_name` bytes arriving after FILE payload
- No progress bar on receiver during Nearby transfer
- Sender showing two progress bars simultaneously
- Overlay icon wrong on receiver side (upload → download)
- Progress bar disappearing on tab switch
- Receive tab showing sender progress
- Overlay covering bottom navigation bar
- Cancel button not working on sender
- Cancel button not working on receiver
- Low transfer speed on old devices (40–80 KB/s via WiFi)

### Added
- `TransferProgressService.isSending` flag for sender/receiver distinction
- Sender includes `size` in `file_name` bytes message for accurate receiver progress
- `ConnectionWidget.isGloballyBusy` — disables send buttons during active transfers
- **In-App Update (Android)** — `UpdateService` with flexible update lifecycle and transfer-safe install deferral

### Changed
- Tab renamed: "Receive / استقبال" → **"My Device / جهازي"**
- AAB size reduced: excluded `x86_64` ABI, compressed assets

---

## [2.0.2] — 2026-06-08

### Fixed
- Multi-file Nearby transfer: single approval for full batch (was per-file)
- Nearby receive race condition (dual pending maps)
- No progress bar on Nearby receiver
- Nearby disconnect during transfer
- `stop()` during active transfer
- Device list flicker during batch transfers
- Low transfer speed via decoupled write loop (`RandomAccessFile`)
- Files tab not refreshing after receive
- Sort case-sensitivity

### Added
- `ConnectionRequest` carries `fileCount` and `fileNames`
- Approval dialog shows file list and total size
- `NearbyTransfer.sendBatchFiles()` — single-approval batch send
- `TransferProgressService._isBatchActive` flag

---

## [2.0.1] — 2026-06-07

### Fixed
- Windows device discovery (UDP broadcast + IP detection)
- File open on Android via FileProvider
- Sort chip contrast in files tab

### Added
- Network mode selector (WiFi / LAN) in desktop sidebar
- Window position/size persistence on Windows
- QR code for Android download on Windows/Linux
- PC download banner on Android receive tab
- Desktop notifications (Windows/Linux)
- Multi-file transfer with dual progress bars
- TV UI redesigned to match desktop style
- `build_windows.bat` + Inno Setup Windows installer

---

## [2.0.0] — 2026-04-01

### Added
- Full UI redesign with dark/light mode
- Android TV support with remote control navigation
- Nearby Connections (Android ↔ Android)
- UDP broadcast discovery (Desktop ↔ Android)
- HTTP transfer engine
- Arabic/English with RTL
- Files tab with categories and sort
- APK sharing between Android devices

---

## [1.0.0] — 2025-12-01

### Initial release
- Basic WiFi file sharing between Android devices
