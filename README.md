# Apex File Share

<div align="center">

**Fast, secure, offline file sharing across Android, Windows, Linux, and Android TV.**

[![Version](https://img.shields.io/badge/version-2.0.5-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20TV-lightgrey.svg)]()

[عربي](README.ar.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md)

</div>

---

## Why Apex File Share?

Most file-sharing tools either require an internet connection, charge a subscription, or come from sources you cannot inspect. Apex File Share is fully local — no servers, no accounts, no cloud. Everything stays on your network. The code is open so you can read it, build it, and improve it.

---

## Features

| | |
|---|---|
| 🚀 **Up to 50 MB/s** | Transfer speed over local WiFi |
| 🔍 **Auto-discovery** | Devices appear in 1–3 seconds |
| 📋 **Clipboard monitoring** | Copy text or an image → send it instantly (Windows & Linux) |
| 📦 **Batch transfer** | Send multiple files or a whole folder in one tap |
| 📱 **Share Sheet** | Appears in the Android system share menu |
| 📺 **Android TV** | Full remote-control UI with D-pad navigation |
| 🖥️ **Desktop sidebar** | Pinned devices, network mode selector, notifications |
| 🌙 **Dark / Light / System** | Theme follows OS preference by default |
| 🌍 **Arabic & English** | Full RTL support |
| 🔒 **100% offline** | No internet required — LAN only |
| 🆓 **Free & open source** | MIT license |

---

## Supported Platforms

| Platform | Transfer | Clipboard | Notifications |
|----------|----------|-----------|---------------|
| Android (phone) | ✅ WiFi + Nearby | — | ✅ |
| Android TV | ✅ WiFi | — | ✅ |
| Windows | ✅ WiFi + LAN | ✅ | ✅ |
| Linux | ✅ WiFi + LAN | ✅ | ✅ |

---

## Download

**Android**
- [Google Play](https://play.google.com/store/apps/dev?id=5409981776310932919)
- [APK — GitHub Releases](https://github.com/Apex-Flow-Group/File_Share/releases)

**Windows & Linux**
- [GitHub Releases](https://github.com/Apex-Flow-Group/File_Share/releases)

---

## Build from Source

### Requirements

| Tool | Version |
|------|---------|
| Flutter SDK | latest stable |
| Dart SDK | ≥ 3.0 |
| Android SDK | API 21+ (for Android) |
| Visual Studio Build Tools | 2022 (for Windows) |
| GTK 3 dev headers | `libgtk-3-dev` (for Linux) |
| Inno Setup | 6.x (Windows installer only) |

### Clone

```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
```

### Android

```bash
# Debug APK
flutter build apk --debug

# Release APK (split per ABI — smaller download)
flutter build apk --release --split-per-abi

# Release AAB (Play Store)
flutter build appbundle --release
```

### Windows

```bash
# Debug
flutter build windows --debug

# Release + installer (requires Inno Setup)
build_windows.bat
```

The installer is generated in `installer/Output/`.

### Linux

```bash
# Debug
flutter build linux --debug

# Release
flutter build linux --release

# Optional: build .deb package
chmod +x build_release.sh && ./build_release.sh
```

### Android TV

No separate build needed — the same APK runs on both phone and TV.
The app detects `android.software.leanback` at startup and switches to the TV UI automatically.

---

## Project Structure

```
lib/
├── core/                   # Transfer engine (ApexCore, HTTP, Nearby)
│   ├── apex_core.dart      # Public API — start/stop/send/discover
│   ├── http_transfer.dart  # HTTP sender + receiver (Desktop ↔ any)
│   ├── nearby_transfer.dart
│   ├── nearby_transfer_send.dart
│   └── nearby_transfer_receive.dart
│
├── mobile/                 # Phone & Desktop UI
│   ├── controllers/        # HomeController — state management
│   ├── screens/            # HomeScreen, Settings, Apps selection
│   └── widgets/            # ConnectionWidget, Send/Receive/Files tabs,
│                           # ClipboardBanner, TransferProgressIndicator
│
├── tv/                     # Android TV UI
│   ├── screens/            # TVHomeScreen, TVIntroScreen, TVTourScreen
│   └── widgets/            # TVSendTab, TVFilesTab, TVDetailsPanel,
│                           # TVFileBrowser, TVFocusableButton
│
├── services/               # Background services
│   ├── clipboard_monitor_service.dart
│   ├── discovery_service.dart
│   ├── file_operations_service.dart
│   ├── file_storage_service.dart
│   ├── folder_zip_service.dart
│   ├── pinned_devices_service.dart
│   ├── settings_service.dart
│   └── transfer_progress_service.dart
│
├── screens/                # Shared screens (Splash, Intro, About)
├── shared/                 # Reusable widgets (BottomSheet, Snackbar, etc.)
├── models/                 # Device, FileReceivedEvent, ConnectionRequest
├── managers/               # DeviceManager, PermissionManager
├── utils/                  # PlatformDetector, FileUtils, ApexLogger
└── main.dart               # Entry point

android/                    # Android native (FileProvider, Share Sheet, Nearby)
windows/runner/             # Win32 window + WM_CLIPBOARDUPDATE handler
linux/runner/               # GTK window + GTK clipboard signal handler
```

---

## How It Works

### Transfer Protocol

```
Sender                          Receiver
──────                          ────────
UDP broadcast (45679) ──────►  UDP listen → reply with device info
                       ◄──────

HTTP POST /request ──────────►  Show accept dialog
                   ◄────────── 200 OK / 403 Rejected

HTTP POST /upload  ──────────►  Stream to disk (chunked, cancellable)
  (chunked, 256 KB)
```

- **Desktop ↔ any**: HTTP over TCP port `45678`
- **Android ↔ Android**: Google Nearby Connections (Bluetooth/WiFi Direct)
- **Discovery**: mDNS via Bonsoir + UDP broadcast fallback

### Clipboard (Windows & Linux)

On Windows the native Win32 message `WM_CLIPBOARDUPDATE` fires on every clipboard change.
On Linux the GTK `owner-change` signal on `GDK_SELECTION_CLIPBOARD` does the same.
Both write a temp file (`/tmp/apex_clip_*.{txt,png}`) and push the path to Dart via `MethodChannel("com.apex.core/clipboard")`.

---

## Troubleshooting

**Devices not found**
- Both devices must be on the same WiFi network (same subnet)
- Restart the app on both sides
- On Windows — add a firewall exception:
  ```cmd
  netsh advfirewall firewall add rule name="ApexFileShare-UDP" dir=in action=allow protocol=UDP localport=45679
  netsh advfirewall firewall add rule name="ApexFileShare-TCP" dir=in action=allow protocol=TCP localport=45678
  ```

**Transfer fails**
- Check that port `45678` (TCP) is not blocked
- On Linux — check `ufw` or `firewalld` rules

**Clipboard banner not appearing (Linux)**
- Make sure the app was built with the latest `linux/runner/my_application.cc`
- Copy something *after* the app is running (the signal only fires on new clipboard changes)

**File won't open after receiving (Android)**
- Grant storage permissions on first launch

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the full guide.

Quick summary:
1. Fork → create a branch from `develop`
2. Make your changes
3. `flutter analyze` must pass with no issues
4. Open a Pull Request targeting `develop`

---

## License

[MIT License](LICENSE) — free to use, modify, and distribute.

---

<div align="center">

Built with Flutter by [Apex Flow Group](https://github.com/Apex-Flow-Group)

</div>
