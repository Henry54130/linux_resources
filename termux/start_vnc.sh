#!/bin/bash
###############################################################################
#  start_vnc.sh — VNC Desktop Launcher (Foreground Run & Multi-Device Access)
#
#  Supports running directly inside PRoot Linux or from Termux Host.
#  Runs in FOREGROUND by default (Press Ctrl+C to cleanly stop).
#  Listens on 0.0.0.0 (Port 5901) for direct LAN & local connection.
#  Fixes X11 default "X" mouse cursor -> Standard arrow pointer (left_ptr).
###############################################################################
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

DISPLAY_NUM=":1"
VNC_PORT=5901
SSH_PORT=8022
RESOLUTION="${1:-1280x720}"
COLOR_DEPTH="${2:-24}"

# Detect if running inside PRoot environment
if [ -f /etc/debian_version ] || [ -f /etc/os-release ] && [ "$PREFIX" != "/data/data/com.termux/files/usr" ]; then
    IN_PROOT=1
else
    IN_PROOT=0
fi

# Acquire wake lock if available to prevent Android CPU sleep
termux-wake-lock 2>/dev/null || true
/data/data/com.termux/files/usr/bin/termux-wake-lock 2>/dev/null || true

# Graceful cleanup handler on Ctrl+C / Termination
cleanup() {
    echo ""
    echo -e "${YELLOW}[!] 正在關閉 VNC 服務與桌面程序...${NC}"
    pkill -9 -f "Xvnc ${DISPLAY_NUM}" 2>/dev/null || true
    pkill -9 -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null || true
    pkill -9 -f "x11vnc" 2>/dev/null || true
    pkill -9 -f "openbox" 2>/dev/null || true
    pkill -9 -f "tint2" 2>/dev/null || true
    pkill -9 -f "pcmanfm" 2>/dev/null || true
    rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 /data/data/com.termux/files/usr/tmp/.X1-lock /data/data/com.termux/files/usr/tmp/.X11-unix/X1 2>/dev/null || true
    
    termux-wake-unlock 2>/dev/null || true
    /data/data/com.termux/files/usr/bin/termux-wake-unlock 2>/dev/null || true

    echo -e "${GREEN}${BOLD}✓ VNC 服務已成功關閉。${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM SIGHUP

# Function to launch VNC server and desktop session inside Linux
start_linux_vnc_session() {
    export DISPLAY="${DISPLAY_NUM}"
    export XCURSOR_THEME=Adwaita
    export XCURSOR_SIZE=24
    export XDG_CURRENT_DESKTOP=Openbox
    export XDG_SESSION_TYPE=x11
    LOG_DIR="/tmp"

    echo -e "${GREEN}[+]${NC} 清理殘留的 VNC 服務與鎖定檔..."
    pkill -9 -f "Xvnc ${DISPLAY_NUM}" 2>/dev/null || true
    pkill -9 -f "Xvfb ${DISPLAY_NUM}" 2>/dev/null || true
    pkill -9 -f "x11vnc" 2>/dev/null || true
    pkill -9 -f "openbox" 2>/dev/null || true
    pkill -9 -f "tint2" 2>/dev/null || true
    pkill -9 -f "pcmanfm" 2>/dev/null || true
    rm -rf /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/.X${DISPLAY_NUM#:}-lock /tmp/.X11-unix/X${DISPLAY_NUM#:} 2>/dev/null || true
    mkdir -p /tmp/.X11-unix 2>/dev/null || true

    # 鏈結 VirGL GPU socket
    if [ -S /data/data/com.termux/files/usr/tmp/.virgl_test ]; then
        ln -sf /data/data/com.termux/files/usr/tmp/.virgl_test /tmp/.virgl_test 2>/dev/null || true
        export GALLIUM_DRIVER=virpipe
        export MESA_GL_VERSION_OVERRIDE=4.0
        export MESA_GLES_VERSION_OVERRIDE=3.2
        unset LIBGL_ALWAYS_SOFTWARE 2>/dev/null || true
    elif [ -S /tmp/.virgl_test ]; then
        export GALLIUM_DRIVER=virpipe
        export MESA_GL_VERSION_OVERRIDE=4.0
        export MESA_GLES_VERSION_OVERRIDE=3.2
        unset LIBGL_ALWAYS_SOFTWARE 2>/dev/null || true
    else
        # No virgl socket — let Mesa auto-detect, do NOT force software
        unset GALLIUM_DRIVER 2>/dev/null || true
        unset MESA_GL_VERSION_OVERRIDE 2>/dev/null || true
        unset MESA_GLES_VERSION_OVERRIDE 2>/dev/null || true
        unset LIBGL_ALWAYS_SOFTWARE 2>/dev/null || true
    fi

    # 啟動 TigerVNC Server (監聽所有介面 0.0.0.0，支援區網與本機直連)
    echo -e "${GREEN}[+]${NC} 啟動 TigerVNC Server (${DISPLAY_NUM}, ${RESOLUTION}, 埠號 ${VNC_PORT})..."
    setsid Xvnc "${DISPLAY_NUM}" \
        -geometry "${RESOLUTION}" \
        -depth "${COLOR_DEPTH}" \
        -rfbport "${VNC_PORT}" \
        -SecurityTypes None \
        -pn </dev/null > "$LOG_DIR/xvnc.log" 2>&1 &

    sleep 1.5

    if ! pgrep -f "Xvnc ${DISPLAY_NUM}" > /dev/null; then
        echo -e "${RED}[✗] Xvnc 啟動失敗，日誌內容：${NC}"
        cat "$LOG_DIR/xvnc.log" 2>/dev/null || true
        exit 1
    fi

    # 【重要修復】設定滑鼠指標為標準箭頭 (left_ptr)，解決 X 叉叉游標問題
    echo -e "${GREEN}[+]${NC} 設定滑鼠指標為標準箭頭 (left_ptr)..."
    xsetroot -cursor_name left_ptr -solid '#2c3e50' 2>/dev/null || true

    # 啟動 D-Bus
    if command -v dbus-launch &>/dev/null && [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        eval "$(dbus-launch --sh-syntax --exit-with-session 2>/dev/null || true)"
    fi

    # 啟動工作列 (tint2) 與桌面管理器 (pcmanfm)
    echo -e "${GREEN}[+]${NC} 啟動工作列 (tint2) 與桌面管理器 (pcmanfm)..."
    setsid tint2 </dev/null > "$LOG_DIR/tint2.log" 2>&1 &
    (setsid pcmanfm --desktop </dev/null > "$LOG_DIR/pcmanfm.log" 2>&1 &) 2>/dev/null || true

    # 啟動終端機 (lxterminal 或 xterm)
    if command -v lxterminal &>/dev/null; then
        setsid lxterminal </dev/null > /dev/null 2>&1 &
    elif command -v xterm &>/dev/null; then
        setsid xterm </dev/null > /dev/null 2>&1 &
    fi

    sleep 0.5
    # 再次設定游標以確保 openbox 載入時為箭頭
    xsetroot -cursor_name left_ptr 2>/dev/null || true

    # 確保 SSH 服務開啟
    if ! pgrep -f "sshd" >/dev/null 2>&1; then
        /data/data/com.termux/files/usr/bin/sshd 2>/dev/null || /usr/sbin/sshd 2>/dev/null || true
    fi

    # 取得本機 IP 地址列表
    IP_LIST=$(ip -4 addr show 2>/dev/null | awk '/inet / && !/127.0.0.1/ {print $2}' | cut -d/ -f1 | tr '\n' ' ')
    [ -z "$IP_LIST" ] && IP_LIST="127.0.0.1"
    FIRST_IP=$(echo "$IP_LIST" | awk '{print $1}')
    [ -z "$FIRST_IP" ] && FIRST_IP="<手機_IP>"

    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  🚀 VNC 桌面服務已成功啟動！(前景運行中 Foreground Active)${NC}"
    echo -e "  ${BOLD}顯示螢幕${NC}   : ${DISPLAY_NUM}"
    echo -e "  ${BOLD}解析度${NC}     : ${RESOLUTION} @ ${COLOR_DEPTH}-bit"
    echo -e "  ${BOLD}滑鼠游標${NC}   : 標準箭頭 (left_ptr ✓)"
    echo -e "  ${BOLD}VNC 埠號${NC}   : ${VNC_PORT}"
    echo -e "  ${BOLD}SSH 埠號${NC}   : ${SSH_PORT}"
    echo -e "  ${BOLD}可用 IP${NC}    : ${IP_LIST}"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${BOLD}🔒 方式 A：透過 SSH Tunnel 安全連線（推薦電腦端）${NC}"
    echo -e "  ${GREEN}步驟 1 — 在電腦終端機 (PowerShell / Terminal) 建立 SSH 通道：${NC}"
    echo -e "     ${CYAN}ssh -N -L 5901:127.0.0.1:5901 -p ${SSH_PORT} root@${FIRST_IP}${NC}"
    echo -e "  ${GREEN}步驟 2 — 在電腦 VNC Viewer / Remmina 連線：${NC}"
    echo -e "     位址：${CYAN}127.0.0.1:5901${NC}  或  ${CYAN}localhost:5901${NC}"
    echo -e "     密碼：${YELLOW}無密碼 (None)${NC}"
    echo ""
    echo -e "  ${BOLD}🌐 方式 B：區網直接連線（同一 WiFi 下）${NC}"
    echo -e "     位址：${CYAN}${FIRST_IP}:5901${NC}"
    echo -e "     密碼：${YELLOW}無密碼 (None)${NC}"
    echo ""
    echo -e "  ${YELLOW}${BOLD}💡 前景模式運行中：保持此視窗開啟。按 [Ctrl + C] 可退出並清理桌面。${NC}"
    echo ""

    echo -e "${GREEN}[+]${NC} 啟動 Openbox 視窗管理器 (前景阻塞)..."
    openbox || true
    cleanup
}

if [ "$IN_PROOT" -eq 1 ]; then
    # ── 運行環境：PRoot Linux 內部 ──
    echo -e "${CYAN}[*] 檢測到目前位於 PRoot Linux 容器內...${NC}"
    start_linux_vnc_session
else
    # ── 運行環境：Termux Host ──
    echo -e "${CYAN}[*] 檢測到目前位於 Termux 主機端...${NC}"

    # 1. 啟動 Termux 原生 SSH 服務 (可選)
    if command -v sshd &>/dev/null; then
        echo -e "${GREEN}[+]${NC} 正在啟動 Termux SSH 服務 (Port ${SSH_PORT})..."
        sshd 2>/dev/null || true
    fi

    # 2. 啟動 VirGL GPU 伺服器 (Termux Host)
    if command -v virgl_test_server_android &>/dev/null; then
        echo -e "${GREEN}[+]${NC} 啟動 VirGL GPU 伺服器..."
        pkill -9 -f virgl 2>/dev/null || true
        rm -f /tmp/.virgl_test /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null || true
        virgl_test_server_android &
        sleep 1
    fi

    # 3. 登入 Ubuntu 容器啟動 VNC (前景阻塞運行)
    proot-distro login ubuntu --shared-tmp -- bash -c "
    $(declare -f start_linux_vnc_session)
    $(declare -f cleanup)
    DISPLAY_NUM='${DISPLAY_NUM}'
    VNC_PORT='${VNC_PORT}'
    RESOLUTION='${RESOLUTION}'
    COLOR_DEPTH='${COLOR_DEPTH}'
    start_linux_vnc_session
    "
fi
