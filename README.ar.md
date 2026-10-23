# Apex File Share

<div align="center">

**مشاركة الملفات بسرعة وأمان وبدون إنترنت بين أندرويد وويندوز ولينكس وتلفاز أندرويد.**

[![الإصدار](https://img.shields.io/badge/الإصدار-2.0.5-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg)](https://flutter.dev)
[![الرخصة](https://img.shields.io/badge/رخصة-MIT-green.svg)](LICENSE)
[![المنصات](https://img.shields.io/badge/المنصات-Android%20%7C%20Windows%20%7C%20Linux%20%7C%20TV-lightgrey.svg)]()

[English](README.md) · [سجل التغييرات](CHANGELOG.md) · [المساهمة](CONTRIBUTING.md)

</div>

---

## لماذا Apex File Share؟

معظم أدوات مشاركة الملفات إما تتطلب إنترنت، أو تحتاج اشتراكاً، أو تأتي من مصادر لا تعرف محتواها. Apex File Share يعمل محلياً بالكامل — لا خوادم، لا حسابات، لا سحابة. كل شيء يبقى داخل شبكتك. الكود مفتوح تستطيع قراءته وبناءه وتطويره.

---

## المميزات

| | |
|---|---|
| 🚀 **حتى 50 MB/s** | سرعة النقل عبر WiFi المحلي |
| 🔍 **اكتشاف تلقائي** | تظهر الأجهزة خلال 1–3 ثوانٍ |
| 📋 **مراقبة الحافظة** | انسخ نصاً أو صورة → أرسلها فوراً (ويندوز ولينكس) |
| 📦 **إرسال دفعي** | أرسل عدة ملفات أو مجلداً كاملاً بضغطة واحدة |
| 📱 **Share Sheet** | يظهر في قائمة المشاركة بنظام أندرويد |
| 📺 **Android TV** | واجهة كاملة بالريموت كونترول |
| 🖥️ **شريط جانبي للكمبيوتر** | أجهزة مثبّتة واختيار الشبكة وإشعارات |
| 🌙 **ليلي / نهاري / نظام** | الثيم يتبع إعداد الجهاز تلقائياً |
| 🌍 **عربي وإنجليزي** | دعم كامل للغة العربية واتجاه RTL |
| 🔒 **بدون إنترنت تماماً** | نقل محلي عبر الشبكة الداخلية فقط |
| 🆓 **مجاني ومفتوح المصدر** | رخصة MIT |

---

## المنصات المدعومة

| المنصة | النقل | الحافظة | الإشعارات |
|--------|-------|---------|-----------|
| Android (هاتف) | ✅ WiFi + Nearby | — | ✅ |
| Android TV | ✅ WiFi | — | ✅ |
| Windows | ✅ WiFi + LAN | ✅ | ✅ |
| Linux | ✅ WiFi + LAN | ✅ | ✅ |

---

## التحميل

**أندرويد**
- [Google Play](https://play.google.com/store/apps/dev?id=5409981776310932919)
- [APK — GitHub Releases](https://github.com/Apex-Flow-Group/File_Share/releases)

**ويندوز ولينكس**
- [GitHub Releases](https://github.com/Apex-Flow-Group/File_Share/releases)

---

## البناء من المصدر

### المتطلبات

| الأداة | الإصدار |
|--------|---------|
| Flutter SDK | أحدث إصدار مستقر |
| Dart SDK | ≥ 3.0 |
| Android SDK | API 21+ (للأندرويد) |
| Visual Studio Build Tools | 2022 (للويندوز) |
| مكتبات GTK 3 | `libgtk-3-dev` (للينكس) |
| Inno Setup | 6.x (للـ installer على ويندوز فقط) |

### الاستنساخ

```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
```

### أندرويد

```bash
# APK للتطوير
flutter build apk --debug

# APK للإصدار (مقسّم حسب المعالج — حجم أصغر)
flutter build apk --release --split-per-abi

# AAB لمتجر Google Play
flutter build appbundle --release
```

### ويندوز

```bash
# للتطوير
flutter build windows --debug

# للإصدار + installer (يتطلب Inno Setup)
build_windows.bat
```

الـ installer ينتج في `installer/Output/`.

### لينكس

```bash
# للتطوير
flutter build linux --debug

# للإصدار
flutter build linux --release

# اختياري: بناء حزمة .deb
chmod +x build_release.sh && ./build_release.sh
```

### تلفاز أندرويد

لا يحتاج بناءً منفصلاً — نفس الـ APK يعمل على الهاتف والتلفاز.
التطبيق يكتشف `android.software.leanback` عند التشغيل وينتقل لواجهة TV تلقائياً.

---

## هيكل المشروع

```
lib/
├── core/                   # محرك النقل (ApexCore، HTTP، Nearby)
│   ├── apex_core.dart      # الواجهة العامة — تشغيل/إيقاف/إرسال/اكتشاف
│   ├── http_transfer.dart  # إرسال واستقبال HTTP (كمبيوتر ↔ أي جهاز)
│   ├── nearby_transfer.dart
│   ├── nearby_transfer_send.dart
│   └── nearby_transfer_receive.dart
│
├── mobile/                 # واجهة الهاتف والكمبيوتر
│   ├── controllers/        # HomeController — إدارة الحالة
│   ├── screens/            # HomeScreen، الإعدادات، اختيار التطبيقات
│   └── widgets/            # ConnectionWidget، تبويبات الإرسال/الاستقبال/الملفات،
│                           # ClipboardBanner، مؤشر التقدم
│
├── tv/                     # واجهة Android TV
│   ├── screens/            # TVHomeScreen، TVIntroScreen، TVTourScreen
│   └── widgets/            # TVSendTab، TVFilesTab، TVDetailsPanel،
│                           # TVFileBrowser، TVFocusableButton
│
├── services/               # خدمات الخلفية
│   ├── clipboard_monitor_service.dart
│   ├── discovery_service.dart
│   ├── file_operations_service.dart
│   ├── file_storage_service.dart
│   ├── folder_zip_service.dart
│   ├── pinned_devices_service.dart
│   ├── settings_service.dart
│   └── transfer_progress_service.dart
│
├── screens/                # شاشات مشتركة (Splash، Intro، About)
├── shared/                 # Widgets مشتركة (BottomSheet، Snackbar...)
├── models/                 # Device، FileReceivedEvent، ConnectionRequest
├── managers/               # DeviceManager، PermissionManager
├── utils/                  # PlatformDetector، FileUtils، ApexLogger
└── main.dart               # نقطة البداية

android/                    # كود أندرويد الأصلي (FileProvider، Share Sheet، Nearby)
windows/runner/             # نافذة Win32 + معالج WM_CLIPBOARDUPDATE
linux/runner/               # نافذة GTK + معالج إشارة clipboard
```

---

## كيف يعمل التطبيق؟

### بروتوكول النقل

```
المُرسِل                        المستقبل
────────                        ────────
UDP broadcast (45679) ───────►  UDP listen → ردّ بمعلومات الجهاز
                      ◄───────

HTTP POST /request ──────────►  عرض نافذة القبول
                   ◄────────── 200 OK / 403 رفض

HTTP POST /upload  ──────────►  حفظ تدريجي على القرص (قابل للإلغاء)
  (مقسّم، 256 KB لكل جزء)
```

- **كمبيوتر ↔ أي جهاز**: HTTP عبر TCP على البورت `45678`
- **أندرويد ↔ أندرويد**: Google Nearby Connections (بلوتوث / WiFi Direct)
- **الاكتشاف**: mDNS عبر Bonsoir + UDP broadcast كبديل

### الحافظة (ويندوز ولينكس)

على ويندوز: رسالة Win32 `WM_CLIPBOARDUPDATE` تُطلق عند كل تغيير في الحافظة.
على لينكس: إشارة GTK `owner-change` على `GDK_SELECTION_CLIPBOARD` تفعل نفس الشيء.
كلاهما يكتب ملفاً مؤقتاً (`/tmp/apex_clip_*.{txt,png}`) ويُرسل مساره لـ Dart عبر `MethodChannel("com.apex.core/clipboard")`.

---

## استكشاف الأخطاء

**الأجهزة لا تظهر**
- تأكد أن الجهازين على نفس شبكة WiFi (نفس الـ subnet)
- أعد تشغيل التطبيق على الجهازين
- على ويندوز — أضف استثناء في جدار الحماية:
  ```cmd
  netsh advfirewall firewall add rule name="ApexFileShare-UDP" dir=in action=allow protocol=UDP localport=45679
  netsh advfirewall firewall add rule name="ApexFileShare-TCP" dir=in action=allow protocol=TCP localport=45678
  ```

**الإرسال يفشل**
- تأكد أن البورت `45678` (TCP) غير محجوب
- على لينكس — تحقق من قواعد `ufw` أو `firewalld`

**بانر الحافظة لا يظهر على لينكس**
- تأكد أن التطبيق بُني بآخر إصدار من `linux/runner/my_application.cc`
- انسخ شيئاً *بعد* تشغيل التطبيق (الإشارة تُطلق فقط عند التغييرات الجديدة)

**فتح الملف لا يعمل على أندرويد**
- امنح صلاحيات التخزين عند أول تشغيل

---

## المساهمة

راجع [CONTRIBUTING.md](CONTRIBUTING.md) للدليل الكامل.

ملخص سريع:
1. Fork → أنشئ فرعاً من `develop`
2. طبّق تغييراتك
3. `flutter analyze` يجب أن يمر بدون أخطاء
4. افتح Pull Request باتجاه `develop`

---

## الرخصة

[رخصة MIT](LICENSE) — حر الاستخدام والتعديل والتوزيع.

---

<div align="center">

بُني بـ Flutter بواسطة [Apex Flow Group](https://github.com/Apex-Flow-Group)

</div>
