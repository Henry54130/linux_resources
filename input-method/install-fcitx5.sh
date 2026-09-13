#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此安裝腳本！"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. 安裝 Fcitx5 輸入法框架與支援庫 ==="
apt-get update
apt-get install -y \
  fcitx5 \
  fcitx5-config-qt \
  fcitx5-data \
  fcitx5-frontend-all \
  fcitx5-frontend-gtk3 \
  fcitx5-frontend-gtk4 \
  fcitx5-frontend-qt5 \
  fcitx5-frontend-qt6 \
  fcitx5-modules \
  im-config

echo "=== 2. 設定預設輸入法框架為 Fcitx5 ==="
im-config -n fcitx5

echo "=== 3. 配置系統環境變數 ==="
mkdir -p /etc/environment.d
cat << 'ENV_EOF' > /etc/environment.d/99-fcitx5.conf
GTK_IM_MODULE=fcitx
QT_IM_MODULE=fcitx
XMODIFIERS=@im=fcitx
SDL_IM_MODULE=fcitx
GLFW_IM_MODULE=ibus
ENV_EOF

echo "=== 4. 配置全域桌面開機自啟動 ==="
mkdir -p /etc/xdg/autostart
install -m 644 "$SCRIPT_DIR/config/org.fcitx.Fcitx5.desktop" /etc/xdg/autostart/org.fcitx.Fcitx5.desktop

echo "Fcitx5 基礎框架安裝與自啟動配置完成！"
exit 0
