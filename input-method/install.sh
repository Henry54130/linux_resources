#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此安裝腳本！"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=========================================="
echo " 開始全自動安裝：Fcitx5 + 小麥注音 + 拼音 "
echo "=========================================="

bash "$SCRIPT_DIR/install-fcitx5.sh"
bash "$SCRIPT_DIR/install-mcbopomofo.sh"
bash "$SCRIPT_DIR/install-pinyin.sh"

echo "=========================================="
echo "所有輸入法模組均已安裝完成！"
echo "請登出重新登入桌面即可開始使用。"
echo "=========================================="
exit 0
