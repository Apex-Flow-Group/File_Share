#!/bin/bash

echo "🚀 بناء Apex Media Streaming..."
echo ""

cd "/mnt/DevData/github/Apex File Share"

# تنظيف
echo "1️⃣ تنظيف..."
flutter clean > /dev/null 2>&1

# تثبيت المكتبات
echo "2️⃣ تثبيت المكتبات..."
flutter pub get

# تحليل الكود
echo "3️⃣ تحليل الكود..."
flutter analyze --no-fatal-infos

# بناء APK
echo "4️⃣ بناء APK..."
flutter build apk --release

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ تم البناء بنجاح!"
    echo ""
    echo "📱 APK موجود في:"
    echo "   build/app/outputs/flutter-apk/app-release.apk"
    echo ""
    ls -lh build/app/outputs/flutter-apk/app-release.apk
    echo ""
    echo "🎉 جاهز للتثبيت!"
else
    echo ""
    echo "❌ فشل البناء"
    exit 1
fi
