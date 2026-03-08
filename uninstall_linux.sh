#!/bin/bash

# 🗑️ Apex Sender - Uninstall Script

echo "╔════════════════════════════════════════╗"
echo "║   🗑️  Apex Sender - Uninstaller       ║"
echo "╚════════════════════════════════════════╝"
echo ""

APP_NAME="ApexSender"
INSTALL_DIR="$HOME/.local/share/$APP_NAME"
BIN_DIR="$HOME/.local/bin"
DESKTOP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/512x512/apps"

echo "⚠️  سيتم حذف التطبيق من النظام"
read -p "هل أنت متأكد؟ (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ تم الإلغاء"
    exit 0
fi

echo ""
echo "🗑️  جاري الحذف..."

# حذف الملفات
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/apexsender"
rm -f "$DESKTOP_DIR/apexsender.desktop"
rm -f "$ICON_DIR/apexsender.png"

# تحديث قاعدة البيانات
update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true

echo ""
echo "✅ تم حذف التطبيق بنجاح"
echo ""
echo "📝 ملاحظة: الملفات المستلمة في ~/Documents/ لم يتم حذفها"
echo ""
