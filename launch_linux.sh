#!/bin/bash

# 🐧 Apex Sender - Linux Launch Script
# يقوم بفتح المنافذ المطلوبة وتشغيل التطبيق

echo "🚀 Apex Sender - Linux Launcher"
echo "================================"
echo ""

# التحقق من Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter غير مثبت!"
    echo "قم بتثبيت Flutter من: https://flutter.dev"
    exit 1
fi

echo "✅ Flutter مثبت"
echo ""

# The firewall is set by install_linux.sh, which uninstall_linux.sh undoes.

echo ""
echo "📦 تحميل المكتبات..."
flutter pub get

echo ""
echo "🎨 تشغيل التطبيق..."
echo "================================"
echo ""

# تشغيل التطبيق
flutter run -d linux

echo ""
echo "👋 تم إغلاق التطبيق"
