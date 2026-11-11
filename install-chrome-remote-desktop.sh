#!/bin/bash
set -e

echo "=================================================="
echo "      開始安裝 Chrome 遠端桌面 (Host 端)          "
echo "=================================================="

# 1. 更新並安裝 wget 與相關工具
echo "👉 1. 更新套件清單並安裝基礎工具..."
sudo apt update
sudo apt install -y wget curl

# 2. 下載並安裝 Chrome 遠端桌面 官方 .deb 包
echo "👉 2. 下載 Chrome 遠端桌面 安裝包..."
TEMP_DEB=$(mktemp)
wget -O "$TEMP_DEB" https://dl.google.com/linux/direct/chrome-remote-desktop_current_amd64.deb

echo "👉 3. 安裝 Chrome 遠端桌面 套件..."
sudo apt install -y "$TEMP_DEB"
rm -f "$TEMP_DEB"

# 3. 建立群組並將目前用戶加入群組中
echo "👉 4. 設定權限群組..."
if ! getent group chrome-remote-desktop > /dev/null; then
    sudo groupadd chrome-remote-desktop
fi
sudo usermod -a -G chrome-remote-desktop "$USER"
echo "✅ 已將用戶 $USER 加入 chrome-remote-desktop 群組"

# 4. 自動產生 Cinnamon 專用且最佳化過的 .chrome-remote-desktop-session 檔
SESSION_FILE="$HOME/.chrome-remote-desktop-session"
echo "👉 5. 檢查並建立桌面會話設定檔..."

if [ -f "$SESSION_FILE" ]; then
    echo "⚠️ 偵測到已存在 $SESSION_FILE，將其備份至 ${SESSION_FILE}.bak..."
    cp "$SESSION_FILE" "${SESSION_FILE}.bak"
fi

cat << 'EOF' > "$SESSION_FILE"
#!/bin/sh
# 1. 隔離本機與遠端的環境變數，防止 D-Bus 名稱衝突造成本地登入失敗
unset DBUS_SESSION_BUS_ADDRESS
unset SESSION_MANAGER

# 2. 設定解析度（此處設定不影響本機螢幕）
export CHROME_REMOTE_DESKTOP_DEFAULT_DESKTOP_SIZES=1024x768,1280x720,1366x768,1440x900,1600x900,1920x1080

# 3. 指定 Cinnamon 桌面環境所需的環境變數
export XDG_CURRENT_DESKTOP=X-Cinnamon
export XDG_SESSION_TYPE=x11
export DESKTOP_SESSION=cinnamon
export XDG_SESSION_DESKTOP=cinnamon

# 4. 在 Cinnamon 啟動前，強制設定虛擬螢幕解析度，避免 layoutManager.primaryMonitor 錯誤
xrandr --output DUMMY0 --mode 1920x1080_60 --primary

# 5. 初始化獨立的 D-Bus session（避免與本地 session 衝突，且讓後續服務和 app 可以正常存取 D-Bus）
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
fi

# 6. 在此 D-Bus 獨立 session 下啟動 gnome-keyring-daemon，並使用獨立的 control-directory，防止干擾本機（DISPLAY :0）的 keyring 控制目錄，同時避免 app 超時 (120s) 卡死或崩潰
mkdir -p "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring-crd"
chmod 0700 "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring-crd"
eval $(gnome-keyring-daemon --start --replace --components=secrets --control-directory="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/keyring-crd" --daemonize)
export GNOME_KEYRING_CONTROL
export GNOME_KEYRING_PID
export SSH_AUTH_SOCK

# 7. 啟動桌面環境（設定輸入法為 fcitx，並自動更新 D-Bus 啟動環境與自啟 fcitx5）
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY GTK_IM_MODULE QT_IM_MODULE XMODIFIERS
fcitx5 -d &
exec /usr/bin/cinnamon-session --session cinnamon
EOF

chmod +x "$SESSION_FILE"
echo "✅ 已建立並最佳化 $SESSION_FILE"

echo "=================================================="
echo "🎉 Chrome 遠端桌面安裝與基本設定完成！"
echo ""
echo "👉 接下來請進行以下手續來啟動遠端存取："
echo "1. 使用「本機瀏覽器」打開網頁："
echo "   https://remotedesktop.google.com/headless"
echo "2. 登入你的 Google 帳號，並點選「設定另一台電腦」開始。"
echo "3. 依據網頁提示點選下方的「複製」按鈕取得一串以 'DISPLAY=...' 開頭的 Debian Linux 設定指令。"
echo "4. 將複製的指令貼到「本機終端機」中執行，並設定 6 位數的 PIN 碼即可！"
echo "=================================================="
