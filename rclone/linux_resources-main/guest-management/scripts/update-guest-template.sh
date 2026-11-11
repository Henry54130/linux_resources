#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此指令！"
    exit 1
fi

SOURCE_HOME="/home/template"
TARGET_TEMPLATE="/etc/guest-template"

if [ ! -d "$SOURCE_HOME" ]; then
    echo "錯誤：找不到來源目錄 $SOURCE_HOME"
    exit 1
fi

mkdir -p "$TARGET_TEMPLATE"

echo "正在將 $SOURCE_HOME 同步至 $TARGET_TEMPLATE ..."
rsync -a --delete \
    --exclude='.cache' \
    --exclude='.local/share/Trash' \
    --exclude='.xsession-errors*' \
    "$SOURCE_HOME/" "$TARGET_TEMPLATE/"

chown -R root:root "$TARGET_TEMPLATE"
echo "範本更新完成！"
exit 0
