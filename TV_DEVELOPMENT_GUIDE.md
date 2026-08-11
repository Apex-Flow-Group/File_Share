# Android TV Development Guide

A reference for building and maintaining the Android TV interface in Apex File Share.
All solutions here were derived from real issues encountered during development.

---

## Table of Contents

1. [AndroidManifest Requirements](#1-androidmanifest-requirements)
2. [Detecting TV vs Phone](#2-detecting-tv-vs-phone)
3. [Permissions on TV](#3-permissions-on-tv)
4. [Remote Control Navigation](#4-remote-control-navigation)
5. [ListView Scroll with Remote](#5-listview-scroll-with-remote)
6. [FilePicker on TV](#6-filepicker-on-tv)
7. [Receiving Files on TV](#7-receiving-files-on-tv)
8. [Correct IP Address Detection](#8-correct-ip-address-detection)
9. [Splash Screen & Startup Speed](#9-splash-screen--startup-speed)
10. [MENU Button Limitation](#10-menu-button-limitation)
11. [TV UI Best Practices](#11-tv-ui-best-practices)
12. [Nearby Connections on TV](#12-nearby-connections-on-tv)
13. [Saving Files on TV](#13-saving-files-on-tv)
14. [Release Build & Signing](#14-release-build--signing)
15. [ADB over WiFi](#15-adb-over-wifi)
16. [Pre-release Checklist](#16-pre-release-checklist)

---

## 1. AndroidManifest Requirements

These entries are mandatory for the app to appear in the TV launcher and pass store review.

```xml
<!-- Required: makes the app visible in the TV store -->
<uses-feature android:name="android.software.leanback" android:required="false" />

<!-- Required: without this the app is rejected from the TV store -->
<uses-feature android:name="android.hardware.touchscreen" android:required="false" />

<!-- Banner shown in the launcher (320x180 px PNG) -->
<application android:banner="@drawable/tv_banner" ...>

<!-- Makes the app appear in the TV home screen -->
<intent-filter>
    <action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.LAUNCHER"/>
    <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
</intent-filter>
```

---

## 2. Detecting TV vs Phone

`Platform.isAndroid` returns `true` on both phone and TV. Use the system feature list to distinguish them.

```dart
// lib/utils/platform_detector.dart
class PlatformDetector {
  bool _isTV = false;
  bool get isTV => _isTV;

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isAndroid) {
      final info = await DeviceInfoPlugin().androidInfo;
      _isTV = info.systemFeatures.contains('android.software.leanback') ||
              info.systemFeatures.contains('android.hardware.type.television');
    }
  }
}
```

Call `initialize()` before `runApp()` but after `WidgetsFlutterBinding.ensureInitialized()`.

---

## 3. Permissions on TV

TV devices do not display the `_PermissionGate` screen, so permissions are never requested and file saves fail silently.

**Fix:** apply `_PermissionGate` on TV the same way as on phone.

```dart
Widget _buildHome(SettingsService settings) {
  if (PlatformDetector.instance.isTV) {
    return settings.hasSeenIntro
        ? _PermissionGate(child: TVHomeScreen(settings: settings))
        : TVIntroScreen(settings: settings);
  }
  // phone path ...
}
```

---

## 4. Remote Control Navigation

### The main pitfall — wrapping content in `Focus`

Putting a `Focus` wrapper around the content area prevents the D-pad from reaching inner widgets.

```dart
// ❌ Wrong — blocks remote from reaching inner elements
Expanded(
  child: Focus(
    focusNode: _contentFocus,
    onKeyEvent: (_, event) { ... },
    child: _buildContent(),
  ),
),

// ✅ Correct — content is rendered directly
Expanded(child: _buildContent()),
```

### Moving focus between Sidebar and Content

```dart
// RTL (Arabic): Left → content, Right → Sidebar
// LTR (English): Right → content, Left → Sidebar
final isRtl = Directionality.of(context) == TextDirection.rtl;
final toContentKey = isRtl
    ? LogicalKeyboardKey.arrowLeft
    : LogicalKeyboardKey.arrowRight;
```

### Exposing a FocusNode per tab

Each tab exposes a `FocusNode` for its first interactive element so the Sidebar can jump to it directly.

```dart
final FocusNode _sendContentFocus = FocusNode();

void _moveToContent() {
  switch (_selectedIndex) {
    case 0: _sendContentFocus.requestFocus();
    case 1: _receiveContentFocus.requestFocus();
    case 2: _filesContentFocus.requestFocus();
  }
}

// Pass the FocusNode to the tab widget
TVSendTab(contentFocusNode: _sendContentFocus, ...)
```

### Preventing focus from leaving the app

```dart
// In the Sidebar — absorb the arrow key that would exit the app
if (event.logicalKey == blockedKey) {
  return KeyEventResult.handled;
}
```

### Focusable button template

```dart
Focus(
  focusNode: _focusNode,
  onKeyEvent: (_, event) {
    if (event is KeyDownEvent &&
        (event.logicalKey == LogicalKeyboardKey.select ||
         event.logicalKey == LogicalKeyboardKey.enter)) {
      onTap();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  },
  child: Builder(builder: (ctx) {
    final hasFocus = Focus.of(ctx).hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        border: hasFocus ? Border.all(color: color, width: 2) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: /* your widget */,
    );
  }),
)
```

---

## 5. ListView Scroll with Remote

`ListView` does not auto-scroll to keep the focused item visible. Add a `GlobalKey` per item and call `Scrollable.ensureVisible` on D-pad navigation.

```dart
final List<GlobalKey> _itemKeys = List.generate(count, (_) => GlobalKey());

// Inside onKeyEvent for arrowDown / arrowUp:
WidgetsBinding.instance.addPostFrameCallback((_) {
  final ctx = _itemKeys[nextIndex].currentContext;
  if (ctx != null) {
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.7,
      duration: const Duration(milliseconds: 150),
    );
  }
});
```

---

## 6. FilePicker on TV

TV devices typically have no file manager installed, so `FilePicker` throws:

```
No application found to handle this action
```

**Fix:** build a custom file browser that reads `/storage/emulated/0/` directly without using an Intent.

```dart
Future<List<String>?> showTVFileBrowser(BuildContext context) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => const TVFileBrowser(),
  );
}
```

The implementation lives in `lib/tv/widgets/tv_file_browser.dart`.

---

## 7. Receiving Files on TV

### HTTP — auto-accept

The standard flow shows an accept dialog that no one sees on TV.

```dart
// http_transfer.dart
if (PlatformDetector.instance.isTV) {
  req.response
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode({'accepted': true}));
  await req.response.close();
  return; // auto-accept
}
```

### Nearby Connections — auto-accept

```dart
// nearby_transfer.dart
Future<void> _handleTransferRequest(String endpointId, Map msg) async {
  if (PlatformDetector.instance.isTV) {
    await Nearby().sendBytesPayload(
      endpointId,
      Uint8List.fromList(utf8.encode(
          jsonEncode({'type': 'response', 'accepted': true}))),
    );
    return; // auto-accept
  }
  // normal dialog flow ...
}
```

Apply the same pattern to `_handleBatchTransferRequest`.

---

## 8. Correct IP Address Detection

Using `Socket.connect('8.8.8.8', 53)` can return `8.8.8.8` instead of the local interface address on some devices.

```dart
// ❌ Wrong
final s = await Socket.connect('8.8.8.8', 53);
final ip = s.address.address; // may return 8.8.8.8

// ✅ Correct — enumerate network interfaces directly
if (Platform.isAndroid || Platform.isIOS) {
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );
  // prefer wlan interface
  for (final iface in interfaces) {
    if (iface.name.toLowerCase().contains('wlan')) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  }
  // fallback to any non-loopback address
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      if (!addr.isLoopback) return addr.address;
    }
  }
}
```

---

## 9. Splash Screen & Startup Speed

`await` calls before `runApp()` block Flutter from painting the first frame, causing a white screen.

```dart
// ❌ Wrong — white screen until all init completes
void main() async {
  await PlatformDetector.instance.initialize();
  await ApexCore.instance.initialize();
  runApp(MyApp());
}

// ✅ Correct — runApp immediately, init happens inside SplashScreen
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}
```

`SplashScreen` runs the async init and navigates forward when it finishes:

```dart
class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInit;
  // ...
  @override
  void initState() {
    super.initState();
    widget.onInit().then((_) => _navigateNext());
  }
}
```

### Native Android splash

```xml
<!-- drawable/launch_background.xml -->
<layer-list>
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap
            android:gravity="center"
            android:src="@drawable/ic_splash"
            android:width="56dp"
            android:height="56dp" />
    </item>
</layer-list>
```

---

## 10. MENU Button Limitation

The MENU button is reserved by the Android TV system and does not reach the app. Do not rely on it for navigation. Place Settings and Refresh as visible focusable items inside the Sidebar instead.

---

## 11. TV UI Best Practices

### Layout

- Use a **Sidebar + Content** layout — not BottomNavigation or TabBar
- Sidebar width: 240–280 dp
- Content area: `Expanded`

### Dialogs

- Use `Dialog` instead of `BottomSheet` — easier to navigate with the remote
- Set `autofocus: true` on the first element inside every dialog
- Add `onKeyEvent` to each interactive element

### Settings panel

- Do not push a new route for settings on TV
- Use a **Details Panel** — slides in from the side with an animation and closes on back arrow

---

## 12. Nearby Connections on TV

Some TV devices report:

```
MISSING_PERMISSION_ACCESS_COARSE_LOCATION
```

This is expected — the app falls back to UDP discovery + HTTP transfer on TV. Nearby Connections is phone-only.

---

## 13. Saving Files on TV

`File.rename()` throws a `Cross-device link` error when the temp directory and the destination are on different partitions.

```dart
try {
  await File(tmpPath).rename(destPath);
} catch (_) {
  // fallback: copy then delete
  await File(tmpPath).copy(destPath);
  await File(tmpPath).delete();
}
```

---

## 14. Release Build & Signing

### Signature mismatch error

```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match
```

Uninstall the old build first:
```bash
adb uninstall com.apexflow.tools.transfer
adb install app-release.apk
```

### Creating a keystore

```bash
keytool -genkeypair -v \
  -keystore android/release.jks \
  -alias apexkey \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass YOUR_STORE_PASS -keypass YOUR_KEY_PASS \
  -dname "CN=ApexFileShare, O=ApexFlowGroup, C=SA"
```

### android/key.properties

```properties
storePassword=YOUR_STORE_PASS
keyPassword=YOUR_KEY_PASS
keyAlias=apexkey
storeFile=release.jks
```

> ⚠️ Add both `key.properties` and `*.jks` to `.gitignore` — never commit signing credentials.

---

## 15. ADB over WiFi

```bash
# Enable ADB on the TV (Developer Options → Network Debugging)
adb connect <tv-ip>:5555

# Install
adb -s <tv-ip>:5555 install -r app.apk

# Run Flutter directly on the TV
flutter run -d <tv-ip>:5555

# View logs for this app only
adb -s <tv-ip>:5555 logcat \
  --pid=$(adb -s <tv-ip>:5555 shell pidof com.apexflow.tools.transfer) -d
```

---

## 16. Pre-release Checklist

- [ ] `android.software.leanback` added with `required="false"`
- [ ] `android.hardware.touchscreen` added with `required="false"`
- [ ] `LEANBACK_LAUNCHER` added to intent-filter
- [ ] `android:banner` set in application tag
- [ ] `PlatformDetector.isTV` returns correct value
- [ ] `_PermissionGate` applied on TV path
- [ ] Every interactive element has a `FocusNode` and `onKeyEvent`
- [ ] `Scrollable.ensureVisible` used in all list views
- [ ] Auto-accept enabled for file transfer on TV (HTTP + Nearby)
- [ ] IP address uses `NetworkInterface.list()` not `Socket.connect`
- [ ] `FilePicker` replaced with built-in `TVFileBrowser`
- [ ] Native splash has an icon (no blank white screen on startup)
- [ ] `runApp()` is called without any `await` before it
- [ ] Signing keystore is in `.gitignore`
