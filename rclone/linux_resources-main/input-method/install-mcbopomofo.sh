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

echo "=== 1. 安裝編譯小麥注音所需的相依套件 ==="
apt-get install -y \
  fcitx5-modules-dev \
  libfcitx5-qt-data \
  libfcitx5-qt1 \
  libfcitx5-qt6-1 \
  libfcitx5config-dev \
  libfcitx5config6 \
  libfcitx5core-dev \
  libfcitx5core7 \
  libfcitx5gclient2 \
  libfcitx5utils-dev \
  libfcitx5utils2 \
  g++ \
  pkg-config \
  cmake \
  extra-cmake-modules \
  gettext \
  libfmt-dev \
  libicu-dev \
  libjson-c-dev \
  git

echo "=== 2. 從原始碼編譯並安裝 小麥注音 ==="
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

git clone --depth 1 https://github.com/openvanilla/fcitx5-mcbopomofo.git "$TEMP_DIR/fcitx5-mcbopomofo"
cd "$TEMP_DIR/fcitx5-mcbopomofo"

cmake -B build -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_BUILD_TYPE=Release
cmake --build build
cmake --install build

update-icon-caches /usr/share/icons/* 2>/dev/null || true

echo "小麥注音 (McBopomofo) 安裝完成！"
exit 0
