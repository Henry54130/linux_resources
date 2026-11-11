#!/bin/bash
set -e

# 檢查 root 權限
if [ "$EUID" -ne 0 ]; then
    echo "請使用 sudo 執行此腳本！"
    echo "範例: sudo ./reboot-to-usb.sh"
    exit 1
fi

echo "=================================================="
echo "         社團電腦救援模式引導程式 (Linux)         "
echo "=================================================="

# 尋找目前隨身碟的開機裝置
SCRIPT_DEVICE=$(df "$0" 2>/dev/null | awk 'NR==2 {print $1}')
echo "當前隨身碟分割區: $SCRIPT_DEVICE"

# 做法 A: 透過 efibootmgr 尋找包含 USB 關鍵字的開機項目並設定 BootNext
USB_BOOT_NUM=$(efibootmgr 2>/dev/null | grep -iE 'usb|ventoy' | head -n 1 | sed -E 's/Boot([0-9A-Fa-f]+)\*.*/\1/')

if [ -n "$USB_BOOT_NUM" ]; then
    echo "找到 USB 開機代號: Boot$USB_BOOT_NUM，正在設定下次強制由該裝置開機..."
    efibootmgr -n "$USB_BOOT_NUM" >/dev/null 2>&1
    echo "設定成功！電腦重開後將直接進入隨身碟。"
    echo "3 秒後自動重開機..."
    sleep 3
    reboot
    exit 0
fi

# 做法 B: 若抓不到明確的 USB BootNext，強制下次重開直接進入 UEFI 韌體選單
echo "未直接鎖定單一 USB 項目，正在設定重開機直接進入 UEFI 韌體選單..."
if command -v systemctl &>/dev/null; then
    systemctl reboot --firmware-setup
else
    reboot
fi
