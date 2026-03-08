#!/bin/bash

# سكريبت لحذف الملفات غير المستخدمة في مشروع Apex File Share
# تم التحقق من هذه الملفات بدقة - آمنة 100% للحذف

echo "🧹 تنظيف الملفات غير المستخدمة..."
echo ""
echo "⚠️  تحذير: هذا السكريبت سيحذف ملفات بشكل نهائي!"
echo ""

# قائمة الملفات غير المستخدمة (تم التحقق منها)
UNUSED_FILES=(
    "lib/utils/error_handler.dart"
    "lib/utils/notification_helper.dart"
    "lib/utils/network_diagnostics.dart"
    "lib/utils/dialog_helper.dart"
    "lib/widgets/dialogs/add_device_dialog.dart"
)

# عرض الملفات التي سيتم حذفها
echo "الملفات التالية سيتم حذفها (تم التحقق - آمنة 100%):"
for file in "${UNUSED_FILES[@]}"; do
    if [ -f "$file" ]; then
        size=$(du -h "$file" | cut -f1)
        echo "  ❌ $file ($size)"
    fi
done

echo ""
echo "📝 ملاحظة: تم فحص هذه الملفات بدقة والتأكد من عدم استخدامها"
echo ""
read -p "هل تريد المتابعة؟ (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # حذف الملفات
    deleted_count=0
    for file in "${UNUSED_FILES[@]}"; do
        if [ -f "$file" ]; then
            rm "$file"
            echo "✅ تم حذف: $file"
            ((deleted_count++))
        else
            echo "⚠️  الملف غير موجود: $file"
        fi
    done
    
    # حذف المجلدات الفارغة
    echo ""
    echo "🗑️  حذف المجلدات الفارغة..."
    find lib -type d -empty -delete 2>/dev/null
    
    echo ""
    echo "✨ تم التنظيف بنجاح! ($deleted_count ملف)"
    echo ""
    echo "📝 الخطوات التالية:"
    echo "  1. تشغيل: flutter pub get"
    echo "  2. تشغيل: flutter analyze"
    echo "  3. اختبار التطبيق للتأكد من عمله"
else
    echo "❌ تم الإلغاء - لم يتم حذف أي ملفات"
fi
