#!/bin/bash

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

echo "📱 البحث عن الأجهزة المتصلة..."

# التحقق من وجود adb
if ! command -v adb &> /dev/null; then
    echo "❌ adb غير مثبت. قم بتثبيته أولاً:"
    echo "   sudo dnf install android-tools"
    exit 1
fi

# التحقق من وجود APK
if [ ! -f "$APK_PATH" ]; then
    echo "❌ لم يتم العثور على APK. قم ببناء التطبيق أولاً:"
    echo "   ./build_apk.sh"
    exit 1
fi

# التحقق من الأجهزة المتصلة
DEVICES=$(adb devices | grep -w "device" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    echo "❌ لا توجد أجهزة متصلة!"
    echo ""
    echo "تأكد من:"
    echo "  1. توصيل الهاتف بكابل USB"
    echo "  2. تفعيل وضع المطور (Developer Mode)"
    echo "  3. تفعيل USB Debugging"
    echo "  4. قبول التصريح على الهاتف"
    exit 1
fi

echo "✅ تم العثور على $DEVICES جهاز"
echo ""
echo "🔄 تثبيت التطبيق..."

adb install -r "$APK_PATH"

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ تم التثبيت بنجاح!"
    echo "🎉 Apex File Share v3.1 + Music Party"
    echo "🚀 يمكنك الآن فتح التطبيق من الهاتف"
else
    echo ""
    echo "❌ فشل التثبيت!"
fi
