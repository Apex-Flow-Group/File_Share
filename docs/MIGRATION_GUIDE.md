# 🔄 دليل الانتقال من النظام القديم إلى الجديد

## 📋 نظرة عامة

هذا الدليل يساعدك على الانتقال من النظام القديم المعقد إلى النظام الجديد البسيط.

---

## ⚠️ قبل البدء

### احفظ نسخة احتياطية!
```bash
# انسخ المشروع الحالي
cp -r "Apex File Share" "Apex File Share - Backup"
```

---

## 🗑️ الخطوة 1: حذف الملفات القديمة

### Core القديم
```bash
cd "Apex File Share/lib/core"

# احذف الملفات القديمة
rm apex_core.dart
rm apex_connection.dart
rm connection_manager.dart
rm connection_state_machine.dart
rm apex_transfer_manager.dart
rm discovery_manager.dart
rm discovery_provider.dart
rm discovery_events.dart
rm udp_discovery_provider.dart
rm mdns_discovery_provider.dart

# احتفظ بـ apex_constants.dart إذا كنت تستخدمه
# وإلا احذفه أيضاً
```

### Security القديم
```bash
cd "Apex File Share/lib"

# احذف مجلد security بالكامل
rm -rf security/
```

### Services القديم
```bash
cd "Apex File Share/lib/services"

# احذف الملفات القديمة
rm apex_http_service.dart
rm file_transfer.dart
```

### UI القديم
```bash
cd "Apex File Share/lib"

# احذف الشاشة القديمة
rm screens/home_screen.dart

# احذف التبويبات القديمة
rm widgets/tabs/send_tab.dart
rm widgets/tabs/receive_tab.dart
```

---

## ✅ الخطوة 2: الملفات الجديدة موجودة بالفعل

الملفات الجديدة تم إنشاؤها بالفعل:
- ✅ `lib/core/apex_core.dart`
- ✅ `lib/screens/home_screen.dart`
- ✅ `lib/widgets/tabs/send_tab.dart`
- ✅ `lib/widgets/tabs/receive_tab.dart`

---

## 🔧 الخطوة 3: تحديث main.dart

### تم التحديث بالفعل! ✅

الملف `lib/main.dart` تم تحديثه ليستخدم:
- `ApexCore` بدلاً من `ApexCore`
- `HomeScreen` (الذي يستورد من `home_screen.dart`)

---

## 📝 الخطوة 4: تحديث الاستيرادات

### إذا كان لديك ملفات أخرى تستخدم النظام القديم:

#### قبل ❌
```dart
import '../core/apex_core.dart';
import '../core/connection_manager.dart';
import '../core/apex_transfer_manager.dart';
```

#### بعد ✅
```dart
import '../core/apex_core.dart';
```

---

## 🔄 الخطوة 5: تحديث الكود

### إرسال ملف

#### قبل ❌
```dart
final connection = await ApexCore.instance.connections
    .getOrCreateConnection(device);

if (connection.currentState != ConnectionState.connected) {
  final connected = await connection.connect();
  if (!connected) return;
}

final success = await connection.sendFile(filePath);
```

#### بعد ✅
```dart
final success = await ApexCore.instance
    .sendFile(filePath, device);
```

### الاستماع للأجهزة

#### قبل ❌
```dart
ApexCore.instance.discovery.eventStream.listen((event) {
  switch (event) {
    case DeviceFound(device: final device):
      // معالجة
      break;
    case DeviceLost(deviceId: final deviceId):
      // معالجة
      break;
  }
});
```

#### بعد ✅
```dart
ApexCore.instance.devicesStream.listen((devices) {
  // devices هي قائمة بجميع الأجهزة المكتشفة
  setState(() {
    _devices = devices;
  });
});
```

### الاستماع للملفات المستلمة

#### قبل ❌
```dart
ApexCore.instance.connections.fileReceivedNotifications
    .listen((notification) {
  // معالجة
});
```

#### بعد ✅
```dart
ApexCore.instance.fileReceivedStream.listen((event) {
  // event يحتوي على fileName, fileSize, fromDevice, filePath
  _showFileReceivedDialog(event);
});
```

### بدء النظام

#### قبل ❌
```dart
await ApexCore.instance.initialize();
await ApexCore.instance.startDiscovery();
```

#### بعد ✅
```dart
await ApexCore.instance.initialize();
await ApexCore.instance.start();
```

### إيقاف النظام

#### قبل ❌
```dart
await ApexCore.instance.stopDiscovery();
await ApexCore.instance.dispose();
```

#### بعد ✅
```dart
await ApexCore.instance.stop();
```

---

## 🧪 الخطوة 6: الاختبار

### 1. تنظيف المشروع
```bash
flutter clean
flutter pub get
```

### 2. التشغيل
```bash
flutter run
```

### 3. اختبار الميزات
- ✅ اكتشاف الأجهزة
- ✅ إرسال ملف
- ✅ استقبال ملف
- ✅ عرض الملفات
- ✅ حذف الملفات

---

## 🐛 استكشاف الأخطاء

### خطأ: Cannot find 'ApexCore'

**الحل:**
```dart
// استبدل
import '../core/apex_core.dart';

// بـ
import '../core/apex_core.dart';

// واستبدل
ApexCore.instance

// بـ
ApexCore.instance
```

### خطأ: Cannot find 'ConnectionManager'

**الحل:**
لا تحتاج `ConnectionManager` بعد الآن!
استخدم `ApexCore.instance.sendFile()` مباشرة.

### خطأ: Cannot find 'ApexTransferManager'

**الحل:**
لا تحتاج `ApexTransferManager` بعد الآن!
استخدم `ApexCore.instance.sendFile()` مباشرة.

### خطأ: Cannot find 'DiscoveryManager'

**الحل:**
لا تحتاج `DiscoveryManager` بعد الآن!
استمع لـ `ApexCore.instance.devicesStream` مباشرة.

---

## 📊 جدول التحويل السريع

| القديم ❌ | الجديد ✅ |
|----------|----------|
| `ApexCore` | `ApexCore` |
| `ApexCore.instance.startDiscovery()` | `ApexCore.instance.start()` |
| `ApexCore.instance.stopDiscovery()` | `ApexCore.instance.stop()` |
| `ApexCore.instance.discovery.eventStream` | `ApexCore.instance.devicesStream` |
| `ApexCore.instance.connections.getOrCreateConnection()` | `ApexCore.instance.sendFile()` |
| `connection.sendFile()` | `ApexCore.instance.sendFile()` |
| `ApexCore.instance.connections.fileReceivedNotifications` | `ApexCore.instance.fileReceivedStream` |

---

## ✅ قائمة التحقق

### قبل الانتقال
- [ ] حفظ نسخة احتياطية
- [ ] قراءة هذا الدليل كاملاً
- [ ] فهم التغييرات الأساسية

### أثناء الانتقال
- [ ] حذف الملفات القديمة
- [ ] التحقق من الملفات الجديدة
- [ ] تحديث الاستيرادات
- [ ] تحديث الكود

### بعد الانتقال
- [ ] تنظيف المشروع
- [ ] اختبار جميع الميزات
- [ ] التحقق من عدم وجود أخطاء
- [ ] حذف النسخة الاحتياطية (اختياري)

---

## 🎯 الفوائد بعد الانتقال

### ما ستلاحظه فوراً:

1. **أسرع** ⚡
   - اكتشاف أسرع للأجهزة
   - نقل أسرع للملفات
   - استجابة أسرع للواجهة

2. **أبسط** 🎨
   - كود أقل
   - منطق أوضح
   - أسهل في الفهم

3. **أقل أخطاء** 🐛
   - استقرار أفضل
   - أخطاء أقل
   - معالجة أفضل

4. **أسهل صيانة** 🔧
   - إضافة ميزات أسهل
   - إصلاح أخطاء أسرع
   - تطوير أسرع

---

## 📚 موارد إضافية

### التوثيق
- 📖 [دليل البدء السريع](QUICK_START.md)
- 📊 [مقارنة النظام القديم والجديد](COMPARISON.md)
- 🏗️ [توثيق النظام الجديد](NEW_SYSTEM_DOCUMENTATION.md)
- 📝 [ملخص إعادة الهيكلة](REFACTORING_SUMMARY_NEW.md)

### الكود
- 💻 [apex_core.dart](lib/core/apex_core.dart)
- 🖥️ [home_screen.dart](lib/screens/home_screen.dart)
- 📤 [send_tab.dart](lib/widgets/tabs/send_tab.dart)
- 📥 [receive_tab.dart](lib/widgets/tabs/receive_tab.dart)

---

## 🆘 الدعم

### إذا واجهت مشكلة:

1. **راجع هذا الدليل مرة أخرى**
2. **اقرأ التوثيق الجديد**
3. **تحقق من الأمثلة في الكود**
4. **افتح issue على GitHub**

### إذا نجح الانتقال:

1. ⭐ أعطِ المشروع نجمة
2. 📢 شارك تجربتك
3. 🤝 ساهم في التطوير

---

## 🎉 تهانينا!

إذا وصلت إلى هنا، فقد نجحت في الانتقال إلى النظام الجديد! 🎊

**استمتع بالسرعة والبساطة! ⚡**

---

<div align="center">

**صُنع بـ ❤️ باستخدام Flutter**

⭐ لا تنسَ إعطاء المشروع نجمة! ⭐

</div>

---

**آخر تحديث:** ${DateTime.now().toString().split('.')[0]}
**الإصدار:** 3.0.0 (النظام الجديد)
