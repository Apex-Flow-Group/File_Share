# دليل تطوير Flutter لـ Android TV
## مرجع شامل للمشاكل والحلول

---

## 1. متطلبات AndroidManifest.xml

### أساسيات لا تعمل التطبيق على TV بدونها

```xml
<!-- إلزامي: يجعل التطبيق يظهر في متجر TV -->
<uses-feature android:name="android.software.leanback" android:required="false" />

<!-- إلزامي: بدونه يُرفض التطبيق من متجر TV -->
<uses-feature android:name="android.hardware.touchscreen" android:required="false" />

<!-- البنر الذي يظهر في الـ launcher (320x180 px PNG) -->
<application android:banner="@drawable/tv_banner" ...>

<!-- يجعل التطبيق يظهر في قائمة TV -->
<intent-filter>
    <action android:name="android.intent.action.MAIN"/>
    <category android:name="android.intent.category.LAUNCHER"/>
    <category android:name="android.intent.category.LEANBACK_LAUNCHER"/>
</intent-filter>
```

---

## 2. اكتشاف نوع الجهاز (TV vs Mobile)

### المشكلة
`Platform.isAndroid` يرجع `true` على TV والهاتف معاً.

### الحل
```dart
// lib/utils/platform_detector.dart
class PlatformDetector {
  bool _isTV = false;

  Future<void> initialize() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      _isTV = androidInfo.systemFeatures
              .contains('android.software.leanback') ||
          androidInfo.systemFeatures
              .contains('android.hardware.type.television');
    }
  }
}
```

### ملاحظة مهمة
استدعِ `initialize()` قبل `runApp()` لكن بعد `WidgetsFlutterBinding.ensureInitialized()`.

---

## 3. الصلاحيات على TV

### المشكلة
TV لا تعرض شاشة `_PermissionGate` مما يعني عدم طلب الصلاحيات أبداً وفشل حفظ الملفات صامتاً.

### الحل
```dart
// main.dart - طبّق _PermissionGate على TV أيضاً
Widget _buildHome(SettingsService settings) {
  if (PlatformDetector.instance.isTV) {
    return settings.hasSeenIntro
        ? _PermissionGate(child: TVHomeScreen(settings: settings))
        : TVIntroScreen(settings: settings);  // وليس TVHomeScreen مباشرة
  }
  // ...
}
```

---

## 4. نظام التنقل بالريموت (Focus Management)

### المشكلة الأكبر
وضع `Focus` wrapper حول منطقة المحتوى يمنع الـ focus من الوصول للعناصر الداخلية.

```dart
// ❌ خطأ — يحجب الريموت عن العناصر الداخلية
Expanded(
  child: Focus(
    focusNode: _contentFocus,
    onKeyEvent: (_, event) { ... },
    child: _buildContent(),  // عناصر داخلية لا تستجيب
  ),
),

// ✅ صحيح — المحتوى مباشر بدون غلاف
Expanded(child: _buildContent()),
```

### قاعدة التنقل بين Sidebar والمحتوى
```dart
// RTL (عربي): يسار → محتوى، يمين → Sidebar
// LTR (إنجليزي): يمين → محتوى، يسار → Sidebar
final isRtl = Directionality.of(context) == TextDirection.rtl;
final toContentKey = isRtl
    ? LogicalKeyboardKey.arrowLeft
    : LogicalKeyboardKey.arrowRight;
```

### نقل الـ Focus من Sidebar للمحتوى
```dart
// كل tab يُعرّض FocusNode للعنصر الأول
final FocusNode _sendContentFocus = FocusNode();

void _moveToContent() {
  switch (_selectedIndex) {
    case 0: _sendContentFocus.requestFocus();
    case 1: _receiveContentFocus.requestFocus();
    case 2: _filesContentFocus.requestFocus();
  }
}

// مرّر الـ FocusNode للـ tab
TVSendTab(contentFocusNode: _sendContentFocus, ...)
```

### منع خروج الـ focus من التطبيق
```dart
// في Sidebar — ابتلع كل الأسهم
if (event.logicalKey == blockedKey) {
  return KeyEventResult.handled;  // لا تسمح بالخروج
}
```

---

## 5. الـ Scroll لا يتحرك مع الريموت

### المشكلة
`ListView` لا يتابع الـ focus — الريموت ينتقل للعنصر التالي لكن القائمة تبقى ثابتة.

### الحل
```dart
// أضف GlobalKey لكل عنصر
final List<GlobalKey> _itemKeys = [];

// في onKey عند arrowDown/arrowUp
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

## 6. FilePicker لا يعمل على TV

### المشكلة
```
No application found to handle this action
```
TV لا تملك file manager مثبتاً.

### الحل
ابنِ file browser مدمج يتصفح `/storage/emulated/0/` مباشرة بدون Intent:
```dart
Future<List<String>?> showTVFileBrowser(BuildContext context) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => _TVFileBrowser(),  // يتصفح الـ storage مباشرة
  );
}
```

---

## 7. استقبال الملفات لا يعمل على TV

### المشكلة A — HTTP
`handlePermissionRequest` ينتظر رد المستخدم من dialog لا تظهر على TV.

### الحل
```dart
// http_transfer.dart
if (PlatformDetector.instance.isTV) {
  req.response
    ..statusCode = HttpStatus.ok
    ..write(jsonEncode({'accepted': true}));
  await req.response.close();
  return;  // قبول تلقائي
}
```

### المشكلة B — Nearby Connections
`_handleTransferRequest` ينتظر رد المستخدم لكن لا أحد يرد على TV.

### الحل
```dart
// nearby_transfer.dart
Future<void> _handleTransferRequest(String endpointId, Map msg) async {
  if (PlatformDetector.instance.isTV) {
    await Nearby().sendBytesPayload(
      endpointId,
      Uint8List.fromList(utf8.encode(
          jsonEncode({'type': 'response', 'accepted': true}))),
    );
    return;  // قبول تلقائي بدون dialog
  }
  // ... منطق الـ dialog العادي
}
```

### نفس الشيء لـ Batch Request
```dart
Future<void> _handleBatchTransferRequest(...) async {
  if (PlatformDetector.instance.isTV) {
    await Nearby().sendBytesPayload(...accepted: true...);
    return;
  }
  // ...
}
```

---

## 8. عنوان IP خاطئ (يظهر 8.8.8.8)

### المشكلة
```dart
// ❌ خطأ — Socket.connect يرجع عنوان الـ socket وليس الـ interface
final s = await Socket.connect('8.8.8.8', 53);
final ip = s.address.address;  // يرجع 8.8.8.8 على بعض الأجهزة!
```

### الحل
```dart
// ✅ صحيح لـ Android/TV
if (Platform.isAndroid || Platform.isIOS) {
  final interfaces = await NetworkInterface.list(
    includeLinkLocal: false,
    type: InternetAddressType.IPv4,
  );
  // أولوية لـ wlan
  for (final iface in interfaces) {
    if (iface.name.toLowerCase().contains('wlan')) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) return addr.address;
      }
    }
  }
  // fallback
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      if (!addr.isLoopback) return addr.address;
    }
  }
}
```

---

## 9. السبلاش سكرين بطيئة / شاشة بيضاء

### المشكلة
`await` قبل `runApp()` يجعل Flutter لا يبدأ حتى ينتهي الـ init → شاشة بيضاء.

### الحل
```dart
// ❌ خطأ
void main() async {
  await PlatformDetector.instance.initialize();
  await ApexCore.instance.initialize();
  runApp(MyApp());
}

// ✅ صحيح — runApp فوراً والـ init يحدث داخل السبلاش
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BootApp());
}

// السبلاش تعرض animation وتنتقل فور انتهاء الـ init
class SplashScreen extends StatefulWidget {
  final Future<void> Function() onInit;
  // ...
  void initState() {
    widget.onInit().then((_) => _navigate());
  }
}
```

### Native Splash (Android)
```xml
<!-- drawable/launch_background.xml — أيقونة على خلفية ملونة -->
<layer-list>
    <item android:drawable="@color/splash_background" />
    <item>
        <bitmap android:gravity="center"
                android:src="@drawable/ic_splash"
                android:width="56dp"
                android:height="56dp" />
    </item>
</layer-list>
```

---

## 10. زر القائمة (MENU) على الريموت

### المشكلة
زر MENU محجوز للنظام ولا يصل للتطبيق.

### الحل
لا تعتمد على MENU. ضع Settings وRefresh كعناصر مرئية في الـ Sidebar مع FocusNode.

---

## 11. واجهة TV — أفضل الممارسات

### الشاشات
- استخدم layout **Sidebar + Content** بدلاً من BottomNavigation أو TabBar
- الـ Sidebar عرضه 240-280dp
- المحتوى `Expanded`

### الـ Dialogs
- استخدم `Dialog` بدلاً من `BottomSheet` — أسهل للتنقل بالريموت
- أول عنصر في الـ Dialog يأخذ `autofocus: true`
- أضف `onKeyEvent` لكل عنصر قابل للتفاعل

### الأزرار
```dart
// كل زر يحتاج
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
      decoration: BoxDecoration(
        border: hasFocus ? Border.all(color: color, width: 2) : null,
      ),
      child: /* ... */,
    );
  }),
)
```

### الـ Settings على TV
- لا تفتح شاشة جديدة
- استخدم **Details Panel** — يظهر من الجانب (slide animation) ويغلق بسهم العودة

---

## 12. الـ Nearby Connections على TV

### المشكلة
```
MISSING_PERMISSION_ACCESS_COARSE_LOCATION
```
هذا طبيعي على بعض TV — التطبيق يعمل بـ UDP discovery بدلاً من Nearby.

### ملاحظة
التلفاز يعمل بـ **HTTP + UDP** فقط، ليس Nearby. الهواتف تستخدم Nearby.

---

## 13. حفظ الملفات على TV

### `rename()` تفشل بـ Cross-device link
```
FileSystemException: Cannot rename file, errno = 18 (Cross-device link)
```

### الحل
```dart
try {
  await File(tmpPath).rename(destPath);
} catch (_) {
  // Fallback
  await File(tmpPath).copy(destPath);
  await File(tmpPath).delete();
}
```

---

## 14. تثبيت نسخة Release على TV

### مشكلة توقيع مختلف
```
INSTALL_FAILED_UPDATE_INCOMPATIBLE: signatures do not match
```

### الحل
```bash
# احذف القديم أولاً
adb uninstall com.your.package
adb install app-release.apk
```

### إنشاء Keystore
```bash
keytool -genkeypair -v \
  -keystore android/release.jks \
  -alias mykey \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass mypassword -keypass mypassword \
  -dname "CN=MyApp, O=MyOrg, C=SA"
```

### key.properties
```properties
storePassword=mypassword
keyPassword=mypassword
keyAlias=mykey
storeFile=release.jks
```

> ⚠️ أضف `key.properties` و `*.jks` للـ `.gitignore`

---

## 15. اختبار TV عبر ADB WiFi

```bash
# اتصل بالتلفاز
adb connect 192.168.x.x:5555

# تثبيت
adb -s 192.168.x.x:5555 install -r app.apk

# مراقبة اللوق
adb -s 192.168.x.x:5555 logcat --pid=$(adb -s 192.168.x.x:5555 shell pidof com.your.package) -d
```

---

## ملخص Checklist قبل نشر تطبيق على TV

- [ ] `android.software.leanback` مضاف بـ `required="false"`
- [ ] `android.hardware.touchscreen` مضاف بـ `required="false"`
- [ ] `LEANBACK_LAUNCHER` مضاف للـ intent-filter
- [ ] `android:banner` مضاف للـ application
- [ ] `PlatformDetector.isTV` يعمل صح
- [ ] `_PermissionGate` مطبّق على TV
- [ ] كل عنصر تفاعلي له `FocusNode` و `onKeyEvent`
- [ ] `Scrollable.ensureVisible` في القوائم
- [ ] قبول تلقائي للملفات على TV (HTTP + Nearby)
- [ ] IP address يستخدم `NetworkInterface.list()` وليس `Socket.connect`
- [ ] `FilePicker` مستبدل بـ file browser مدمج
- [ ] Native splash يحتوي أيقونة (لا شاشة بيضاء فارغة)
- [ ] `runApp()` بدون `await` قبله
