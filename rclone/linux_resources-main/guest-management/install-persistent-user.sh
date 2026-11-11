#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此腳本！"
    exit 1
fi

TEMPLATE_DIR="/etc/guest-template"

if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "錯誤：找不到範本目錄 $TEMPLATE_DIR！請先完成系統初始化。"
    exit 1
fi

USERNAME="$1"
PASSWORD="$2"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]; then
    echo "使用方式: sudo $0 <使用者名稱> <密碼>"
    echo "範例:     sudo $0 john secret123"
    exit 1
fi

if id -u "$USERNAME" &>/dev/null; then
    echo "錯誤：使用者 '$USERNAME' 已經存在！"
    exit 1
fi

if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "錯誤：帳號格式不合規（請使用小寫英文開頭，僅限小寫英文、數字、底線或破折號）。"
    exit 1
fi

echo "正在建立使用者 '$USERNAME'..."
useradd -m -s /bin/bash "$USERNAME"
echo "$USERNAME:$PASSWORD" | chpasswd

# 移除管理者權限
deluser "$USERNAME" sudo 2>/dev/null || true
deluser "$USERNAME" docker 2>/dev/null || true

# 從範本複製家目錄設定
TARGET_HOME="/home/$USERNAME"
rsync -a "$TEMPLATE_DIR/" "$TARGET_HOME/"
chown -R "$USERNAME:$USERNAME" "$TARGET_HOME"

echo "使用者 '$USERNAME' 建立成功！已套用範本環境且登出不重設。"
exit 0
