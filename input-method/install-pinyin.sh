#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此安裝腳本！"
    exit 1
fi

echo "=== 檢查 Fcitx5 依賴 ==="
if ! command -v fcitx5 &>/dev/null; then
    echo "偵測到尚未安裝 Fcitx5，正在自動執行基礎安裝..."
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    bash "$SCRIPT_DIR/install-fcitx5.sh"
fi

echo "=== 安裝 Fcitx5 拼音組件 (fcitx5-chinese-addons) ==="
apt-get update
apt-get install -y fcitx5-chinese-addons

echo "拼音輸入法安裝完成！"
exit 0
