#!/bin/bash

# 🐧 Apex Sender - Full Linux Installation Script
# يقوم بتثبيت التطبيق بشكل كامل على فيدورا لينكس

set -e

echo "╔════════════════════════════════════════╗"
echo "║   🚀 Apex Sender - Linux Installer    ║"
echo "╚════════════════════════════════════════╝"
echo ""

# الألوان
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# المتغيرات
APP_NAME="ApexSender"
BUILD_NAME="file_share_app"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

# 1. التحقق من المتطلبات
echo "📋 التحقق من المتطلبات..."

if ! command -v flutter &> /dev/null; then
    echo -e "${RED}❌ Flutter غير مثبت!${NC}"
    echo "قم بتثبيت Flutter من: https://flutter.dev"
    exit 1
fi
echo -e "${GREEN}✅ Flutter مثبت${NC}"

# 2. تثبيت المكتبات المطلوبة
echo ""
echo "📦 تثبيت المكتبات المطلوبة..."
sudo dnf install -y gtk3-devel clang cmake ninja-build pkg-config 2>/dev/null || {
    echo -e "${YELLOW}⚠️  تخطي تثبيت المكتبات (قد تكون مثبتة مسبقاً)${NC}"
}

# 3. بناء التطبيق
echo ""
echo "🔨 بناء التطبيق..."
flutter clean
flutter pub get
flutter build linux --release

if [ ! -f "build/linux/x64/release/bundle/$BUILD_NAME" ]; then
    echo -e "${RED}❌ فشل البناء!${NC}"
    exit 1
fi
echo -e "${GREEN}✅ تم البناء بنجاح${NC}"

# 4. إنشاء مجلدات التثبيت
echo ""
echo "📁 إنشاء مجلدات التثبيت..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$BIN_DIR"
mkdir -p "$DESKTOP_DIR"
mkdir -p "$ICON_DIR"

# 5. إيقاف التطبيق إذا كان قيد التشغيل
echo ""
echo "⏸️  إيقاف التطبيق إذا كان قيد التشغيل..."
pkill -f "$BUILD_NAME" 2>/dev/null || true
sleep 1
echo -e "${GREEN}✅ تم التحقق${NC}"

# 6. نسخ الملفات
echo ""
echo "📋 نسخ ملفات التطبيق..."
cp -r build/linux/x64/release/bundle/* "$INSTALL_DIR/"
echo -e "${GREEN}✅ تم نسخ الملفات${NC}"

# 7. إنشاء رابط تنفيذي
echo ""
echo "🔗 إنشاء رابط تنفيذي..."
cat > "$BIN_DIR/apexsender" << EOF
#!/bin/bash
cd "$INSTALL_DIR"
./$BUILD_NAME "\$@"
EOF
chmod +x "$BIN_DIR/apexsender"
echo -e "${GREEN}✅ تم إنشاء الرابط${NC}"

# 8. نسخ الأيقونة
echo ""
echo "🎨 إعداد الأيقونة..."
if [ -f "assets/images/ico.png" ]; then
    cp assets/images/ico.png "$ICON_DIR/apexsender.png"
    echo -e "${GREEN}✅ تم نسخ الأيقونة${NC}"
else
    echo -e "${YELLOW}⚠️  الأيقونة غير موجودة${NC}"
fi

# 9. إنشاء ملف Desktop Entry
echo ""
echo "🖥️  إنشاء اختصار سطح المكتب..."
cat > "$DESKTOP_DIR/apexsender.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Apex Sender
Name[ar]=أبكس سندر
Comment=Share files across devices via WiFi
Comment[ar]=مشاركة الملفات بين الأجهزة عبر الواي فاي
Exec=$BIN_DIR/apexsender
Icon=apexsender
Terminal=false
Categories=Network;FileTransfer;Utility;
Keywords=file;share;transfer;wifi;
StartupNotify=true
EOF
chmod +x "$DESKTOP_DIR/apexsender.desktop"
echo -e "${GREEN}✅ تم إنشاء الاختصار${NC}"

# 10. تحديث قاعدة بيانات التطبيقات
echo ""
echo "🔄 تحديث قاعدة البيانات..."
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

# 11. فتح المنافذ في جدار الحماية
echo ""
echo "🔓 إعداد جدار الحماية..."
if command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --add-port=8888/udp --permanent 2>/dev/null || true
    sudo firewall-cmd --add-port=8080/tcp --permanent 2>/dev/null || true
    sudo firewall-cmd --reload 2>/dev/null || true
    echo -e "${GREEN}✅ تم فتح المنافذ (8888 UDP, 8080 TCP)${NC}"
else
    echo -e "${YELLOW}⚠️  firewall-cmd غير موجود${NC}"
fi

# 12. إضافة PATH إذا لزم الأمر
echo ""
echo "🛤️  التحقق من PATH..."
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  يجب إضافة $BIN_DIR إلى PATH${NC}"
    echo ""
    echo "أضف السطر التالي إلى ~/.bashrc:"
    echo -e "${GREEN}export PATH=\"\$HOME/.local/bin:\$PATH\"${NC}"
    echo ""
    echo "ثم نفذ: source ~/.bashrc"
fi

# 13. الانتهاء
echo ""
echo "╔════════════════════════════════════════╗"
echo "║      ✅ تم التثبيت بنجاح! 🎉         ║"
echo "╚════════════════════════════════════════╝"
echo ""
echo "📍 مسار التثبيت: $INSTALL_DIR"
echo "🚀 لتشغيل التطبيق:"
echo "   • من التيرمينال: apexsender"
echo "   • من قائمة التطبيقات: ابحث عن 'Apex Sender'"
echo ""
echo "🌐 المنافذ المستخدمة:"
echo "   • 8888 (UDP) - اكتشاف الأجهزة"
echo "   • 8080 (TCP) - نقل الملفات"
echo ""
echo "📝 ملاحظات:"
echo "   • تأكد من الاتصال بنفس شبكة WiFi"
echo "   • افتح التطبيق على الأجهزة الأخرى"
echo "   • الملفات تُحفظ في: ~/Documents/"
echo ""
echo "🐧 استمتع بـ Apex Sender على Linux!"
echo ""
