# Apex File Share

**Fast, secure, and offline file sharing between Android, Windows, and Linux.**

[![Version](https://img.shields.io/badge/version-2.0.1-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Linux-lightgrey.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## Features

- 🚀 Transfer speed up to 50 MB/s over local WiFi
- 🔍 Automatic device discovery in 1–3 seconds
- 📱 Works between Android ↔ Windows ↔ Linux
- 📺 Android TV support with remote control
- 🌐 Choose between WiFi or LAN (Windows/Linux)
- 🌙 Dark and light mode
- 🌍 Arabic and English with RTL
- 🔒 No internet — local transfer only
- 🆓 Free and open source

---

## Platforms

| Platform | Status |
|----------|--------|
| Android | ✅ |
| Windows | ✅ |
| Linux | ✅ |
| Android TV | ✅ |

---

## Download

### Android
[![Google Play](https://img.shields.io/badge/Google%20Play-Download-green.svg)](https://play.google.com/store/apps/dev?id=5409981776310932919)
[![APK](https://img.shields.io/badge/APK-Download-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)

### Windows & Linux
[![Releases](https://img.shields.io/badge/GitHub-Releases-181717.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)

---

## Build

### Requirements
- Flutter SDK (latest stable)
- Dart SDK 3.0+
- Android SDK 21+ (for Android)
- Visual Studio Build Tools (for Windows)
- Inno Setup 6 (for Windows installer)

### Android
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
flutter build apk --release --split-per-abi
```

### Windows
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
build_windows.bat
```
Installer is generated in the `installer/` folder.

### Linux
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
flutter build linux --release
```

---

## Troubleshooting

**No devices found?**
- Make sure both devices are on the same WiFi network
- Restart the app
- On Windows: run as administrator or add a firewall exception

**Transfer fails on Windows?**
```cmd
netsh advfirewall firewall add rule name="ApexFileShare" dir=in action=allow protocol=UDP localport=45679
netsh advfirewall firewall add rule name="ApexFileShare-TCP" dir=in action=allow protocol=TCP localport=45678
```

**File won't open on Android?**
Grant storage permissions on first launch.

---

## Project Structure

```
lib/
├── core/          # Core system (ApexCore)
├── services/      # Discovery and transfer services
├── screens/       # App screens
├── widgets/       # UI components
├── models/        # Data models
├── managers/      # Device and permissions management
└── utils/         # Utilities
android/           # Native Android code
windows/           # Native Windows code
```

---

## Contributing

1. Fork the project
2. Create a branch from `develop`
3. Commit your changes
4. Open a Pull Request to `develop`

---

## License

MIT License — Free and open source

---

<div align="center">

Made with ❤️ using Flutter | [apexflow.now](https://apexflow.now)

</div>
