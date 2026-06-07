# Changelog — Apex File Share

All notable changes to this project will be documented in this file.

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
