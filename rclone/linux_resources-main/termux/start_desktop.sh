#!/bin/bash
###############################################################################
#  start_desktop.sh — Termux:X11 Local Desktop Launcher (Foreground Run)
#
#  Supports running directly inside PRoot Linux or from Termux Host.
#  Runs in FOREGROUND by default (Press Ctrl+C to cleanly stop).
#  Fixes X11 default "X" mouse cursor -> Standard arrow pointer (left_ptr).
###############################################################################
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

DISPLAY_NUM=":0"

# Detect if running inside PRoot environment
if [ -f /etc/debian_version ] || [ -f /etc/os-release ] && [ "$PREFIX" != "/data/data/com.termux/files/usr" ]; then
    IN_PROOT=1
else
    IN_PROOT=0
fi

# Acquire wake lock to keep CPU active on Android
termux-wake-lock 2>/dev/null || true
/data/data/com.termux/files/usr/bin/termux-wake-lock 2>/dev/null || true

# Graceful cleanup handler on Ctrl+C / Termination
cleanup() {
    echo ""
    echo -e "${YELLOW}[!] 正在關閉 Termux:X11 桌面程序...${NC}"
    pkill -9 -f "openbox" 2>/dev/null || true
    pkill -9 -f "tint2" 2>/dev/null || true
    pkill -9 -f "pcmanfm" 2>/dev/null || true
    
    if [ "$IN_PROOT" -eq 0 ]; then
        pkill -9 -f "termux-x11 :0" 2>/dev/null || true
        rm -rf /tmp/.X11-unix/X0 /tmp/.X0-lock 2>/dev/null || true
        termux-wake-unlock 2>/dev/null || true
    fi

    echo -e "${GREEN}${BOLD}✓ 桌面程序已完全關閉。${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM SIGHUP

start_linux_desktop_session() {
    export DISPLAY="${DISPLAY_NUM}"
    export XCURSOR_THEME=Adwaita
    export XCURSOR_SIZE=24
    export XDG_CURRENT_DESKTOP=Openbox
    export XDG_SESSION_TYPE=x11
    LOG_DIR="/tmp"

    # 鏈結 Termux:X11 socket 與 VirGL GPU socket
    mkdir -p /tmp/.X11-unix 2>/dev/null || true
    DISPLAY_SOCK="X${DISPLAY_NUM#:}"
    if [ ! -e "/tmp/.X11-unix/${DISPLAY_SOCK}" ] && [ -e "/data/data/com.termux/files/usr/tmp/.X11-unix/${DISPLAY_SOCK}" ]; then
        ln -sf "/data/data/com.termux/files/usr/tmp/.X11-unix/${DISPLAY_SOCK}" "/tmp/.X11-unix/${DISPLAY_SOCK}" 2>/dev/null || true
    fi
    # VirGL GPU socket — set vars only when socket is available
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

    # 檢查 X11 顯示連線
    if command -v xdpyinfo &>/dev/null; then
        if ! xdpyinfo -display "${DISPLAY_NUM}" &>/dev/null; then
            echo -e "${RED}[✗] 無法連線至 X11 顯示螢幕 ${DISPLAY_NUM}！${NC}"
            echo -e "${YELLOW}[!] 請確認 Termux:X11 應用程式已開啟，且 Termux 主機端已執行 termux-x11。${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}[+]${NC} 清理殘留的桌面元件..."
    pkill -9 -f openbox 2>/dev/null || true
    pkill -9 -f tint2 2>/dev/null || true
    pkill -9 -f pcmanfm 2>/dev/null || true

    # 【重要修復】設定滑鼠指標為標準箭頭 (left_ptr)，解決 X 叉叉游標問題
    echo -e "${GREEN}[+]${NC} 設定滑鼠指標為標準箭頭 (left_ptr)..."
    xsetroot -cursor_name left_ptr -solid '#2c3e50' 2>/dev/null || true

    # 啟動 D-Bus
    if command -v dbus-launch &>/dev/null && [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
        eval "$(dbus-launch --sh-syntax --exit-with-session 2>/dev/null || true)"
    fi

    # 背景啟動工作列與桌面管理器
    echo -e "${GREEN}[+]${NC} 啟動工作列 (tint2) 與桌面管理器 (pcmanfm)..."
    setsid tint2 </dev/null > "$LOG_DIR/tint2.log" 2>&1 &
    (setsid pcmanfm --desktop </dev/null > "$LOG_DIR/pcmanfm.log" 2>&1 &) 2>/dev/null || true
    sleep 0.5

    # 再次設定游標以確保 openbox 載入時為箭頭
    xsetroot -cursor_name left_ptr 2>/dev/null || true

    # 啟動終端機 (lxterminal 或 xterm)
    if command -v lxterminal &>/dev/null; then
        setsid lxterminal </dev/null > /dev/null 2>&1 &
    elif command -v xterm &>/dev/null; then
        setsid xterm </dev/null > /dev/null 2>&1 &
    fi

    echo ""
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  🚀 Termux:X11 桌面已啟動！(前景運行中 Foreground Active)${NC}"
    echo -e "  ${BOLD}顯示螢幕${NC}   : ${DISPLAY_NUM}"
    echo -e "  ${BOLD}滑鼠游標${NC}   : 標準箭頭 (left_ptr ✓)"
    echo -e "${CYAN}${BOLD}══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${YELLOW}${BOLD}💡 前景模式運行中：保持此視窗開啟。按 [Ctrl + C] 可退出並清理桌面。${NC}"
    echo ""

    echo -e "${GREEN}[+]${NC} 啟動 Openbox 視窗管理器 (前景阻塞)..."
    openbox || true
    cleanup
}

if [ "$IN_PROOT" -eq 1 ]; then
    # ── 運行環境：PRoot Linux 內部 ──
    echo -e "${CYAN}[*] 檢測到目前位於 PRoot Linux 容器內...${NC}"
    echo -e "${YELLOW}[!] 請確認手機已開啟 Termux:X11 App${NC}"
    start_linux_desktop_session
else
    # ── 運行環境：Termux Host ──
    echo -e "${CYAN}[*] 檢測到目前位於 Termux 主機端...${NC}"

    # 1. 清理舊服務
    pkill -9 -f termux-x11 2>/dev/null || true
    pkill -9 -f virgl 2>/dev/null || true
    rm -rf /tmp/.X11-unix/X0 /tmp/.X0-lock /tmp/.virgl_test /data/data/com.termux/files/usr/tmp/.virgl_test 2>/dev/null || true
    sleep 1

    # 2. 啟動顯示與 GPU
    echo -e "${GREEN}[+]${NC} 啟動 Termux:X11 顯示服務與 VirGL GPU..."
    termux-x11 :0 -ac &
    virgl_test_server_android &
    sleep 1.5

    echo -e "${GREEN}[+]${NC} 開啟 Termux:X11 Android 應用程式..."
    am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity 2>/dev/null || true
    sleep 1.5

    # 3. 進入 Openbox (保持 Session 運行)
    proot-distro login ubuntu --shared-tmp -- bash -c "
    $(declare -f start_linux_desktop_session)
    $(declare -f cleanup)
    DISPLAY_NUM=':0'
    start_linux_desktop_session
    "
fi
