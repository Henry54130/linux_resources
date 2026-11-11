#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
    echo "錯誤：請使用 sudo 執行此安裝腳本！"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== 1. 建立 template 與 guest 帳號 ==="
id -u template &>/dev/null || adduser --gecos "" --disabled-password template
id -u guest &>/dev/null || adduser --gecos "" --disabled-password guest

echo "template:guest" | chpasswd
echo "guest:guest" | chpasswd

deluser template sudo 2>/dev/null || true
deluser guest sudo 2>/dev/null || true
deluser template docker 2>/dev/null || true
deluser guest docker 2>/dev/null || true

echo "=== 2. 限制 Docker 與 Tailscale 執行權限 (chmod 700) ==="
for bin in /usr/bin/docker /usr/bin/dockerd /usr/bin/tailscale /usr/sbin/tailscaled; do
    if [ -f "$bin" ]; then
        chown root:root "$bin"
        chmod 700 "$bin"
        echo "已限制權限: $bin"
    fi
done

echo "=== 3. 部署執行腳本與設定檔至系統目錄 ==="
install -m 755 "$SCRIPT_DIR/scripts/update-guest-template.sh" /usr/local/bin/update-guest-template
install -m 755 "$SCRIPT_DIR/scripts/reset_guest_profile.sh" /usr/local/bin/reset_guest_profile.sh
install -m 755 "$SCRIPT_DIR/install-persistent-user.sh" /usr/local/bin/install-persistent-user

mkdir -p /etc/lightdm/lightdm.conf.d
install -m 644 "$SCRIPT_DIR/config/70-guest-reset.conf" /etc/lightdm/lightdm.conf.d/70-guest-reset.conf
install -m 440 "$SCRIPT_DIR/config/template-sync" /etc/sudoers.d/template-sync

echo "=== 4. 初始化範本目錄 ==="
/usr/local/bin/update-guest-template
/usr/local/bin/reset_guest_profile.sh

echo "=========================================="
echo "          系統部署完成！"
echo "=========================================="
exit 0
