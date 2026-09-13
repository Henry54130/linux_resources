#!/usr/bin/env bash
set -e

TARGET_DIR="$HOME/.local/share/applications"
DESKTOP_FILE="$TARGET_DIR/brave-browser.desktop"

mkdir -p "$TARGET_DIR"

# 優先尋找系統既有的 desktop 檔案
if [ -f "/usr/share/applications/brave-browser.desktop" ]; then
    cp /usr/share/applications/brave-browser.desktop "$DESKTOP_FILE"
elif [ -f "/usr/share/applications/brave-browser-stable.desktop" ]; then
    cp /usr/share/applications/brave-browser-stable.desktop "$DESKTOP_FILE"
else
    echo "找不到系統預設的 brave-browser.desktop，正在終端機尋找路徑..."
fi

# 替換 Exec 啟動參數，加入 --password-store=basic
if [ -f "$DESKTOP_FILE" ]; then
    # 防止重複疊加參數
    sed -i 's/ --password-store=basic//g' "$DESKTOP_FILE"
    # 在可執行路徑後補上參數
    sed -i -E 's|^(Exec=[^ ]+)|\1 --password-store=basic|g' "$DESKTOP_FILE"
    
    if command -v update-desktop-database > /dev/null 2>&1; then
        update-desktop-database "$TARGET_DIR"
    fi
    echo ">> 桌面捷徑已成功更新：$DESKTOP_FILE"
    echo ">> 啟動指令已綁定 --password-store=basic"
else
    echo ">> 錯誤：無法建立桌面捷徑檔案"
    exit 1
fi

echo "修復完成！"
