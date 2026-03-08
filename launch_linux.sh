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

# فتح المنافذ في جدار الحماية (يتطلب sudo)
echo "🔓 فتح المنافذ المطلوبة..."
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --add-port=8888/udp --permanent 2>/dev/null
    sudo firewall-cmd --add-port=8080/tcp --permanent 2>/dev/null
    sudo firewall-cmd --reload 2>/dev/null
    echo "✅ تم فتح المنافذ 8888 (UDP) و 8080 (TCP)"
else
    echo "⚠️  firewall-cmd غير موجود، تخطي إعدادات الجدار الناري"
fi

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
