# Apex File Share

**مشاركة الملفات بسرعة وأمان وبدون إنترنت بين أندرويد وويندوز ولينكس.**

[![Version](https://img.shields.io/badge/version-2.0.1-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)
[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B.svg)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20Windows%20%7C%20Linux-lightgrey.svg)]()
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

---

## المميزات

- 🚀 سرعة نقل حتى 50 MB/s عبر WiFi المحلي
- 🔍 اكتشاف تلقائي للأجهزة خلال 1–3 ثواني
- 📱 يعمل بين أندرويد ↔ ويندوز ↔ لينكس
- 📺 دعم Android TV بالريموت كونترول
- 🌐 اختيار بين WiFi أو LAN (ويندوز/لينكس)
- 🌙 وضع ليلي ونهاري
- 🌍 عربي وإنجليزي مع RTL
- 🔒 بدون إنترنت — نقل محلي فقط
- 🆓 مجاني ومفتوح المصدر

---

## المنصات

| المنصة | الحالة |
|--------|--------|
| Android | ✅ |
| Windows | ✅ |
| Linux | ✅ |
| Android TV | ✅ |

---

## التحميل

### أندرويد
[![Google Play](https://img.shields.io/badge/Google%20Play-تحميل-green.svg)](https://play.google.com/store/apps/dev?id=5409981776310932919)
[![APK](https://img.shields.io/badge/APK-تحميل-blue.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)

### ويندوز ولينكس
[![Releases](https://img.shields.io/badge/GitHub-Releases-181717.svg)](https://github.com/Apex-Flow-Group/File_Share/releases)

---

## البناء

### المتطلبات
- Flutter SDK (أحدث إصدار مستقر)
- Dart SDK 3.0+
- Android SDK 21+ (للأندرويد)
- Visual Studio Build Tools (للويندوز)
- Inno Setup 6 (لإنشاء installer ويندوز)

### أندرويد
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
flutter build apk --release --split-per-abi
```

### ويندوز
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
build_windows.bat
```
الـ installer يُنتج في مجلد `installer/`

### لينكس
```bash
git clone https://github.com/Apex-Flow-Group/File_Share.git
cd File_Share
flutter pub get
flutter build linux --release
```

---

## استكشاف الأخطاء

**لا يظهر أي جهاز؟**
- تأكد أن كلا الجهازين على نفس شبكة WiFi
- أعد تشغيل التطبيق
- على ويندوز: شغّل التطبيق كمدير أو أضف استثناء في جدار الحماية

**فشل الإرسال على ويندوز؟**
```cmd
netsh advfirewall firewall add rule name="ApexFileShare" dir=in action=allow protocol=UDP localport=45679
netsh advfirewall firewall add rule name="ApexFileShare-TCP" dir=in action=allow protocol=TCP localport=45678
```

**فتح الملف لا يعمل على أندرويد؟**
تأكد من منح صلاحيات التخزين عند أول تشغيل.

---

## هيكل المشروع

```
lib/
├── core/          # النواة الرئيسية (ApexCore)
├── services/      # خدمات الاكتشاف والنقل
├── screens/       # شاشات التطبيق
├── widgets/       # مكونات الواجهة
├── models/        # نماذج البيانات
├── managers/      # إدارة الجهاز والصلاحيات
└── utils/         # أدوات مساعدة
android/           # كود أندرويد الأصلي
windows/           # كود ويندوز الأصلي
```

---

## المساهمة

1. Fork المشروع
2. أنشئ branch من `develop`
3. Commit التغييرات
4. افتح Pull Request على `develop`

---

## الترخيص

MIT License — مجاني ومفتوح المصدر

---

<div align="center">

صُنع بـ ❤️ باستخدام Flutter | [apexflow.now](https://apexflow.now)

</div>
