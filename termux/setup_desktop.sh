#!/bin/bash
###############################################################################
#  setup_desktop.sh — Setup Local Desktop (Termux:X11 + VirGL GPU) in Termux
#
#  Run this in TERMUX.
#  It installs Termux:X11 & VirGL on the Termux host, and installs Openbox,
#  Tint2, PCManFM, fonts, and Mesa GPU drivers in PRoot Ubuntu.
###############################################################################
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
header(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

header "Termux:X11 Desktop & GPU Setup"

# ── 1. Install Termux Host Packages ──────────────────────────────────────────
header "1/3  Installing Termux host packages (X11 + VirGL)"
pkg update -y
pkg install -y x11-repo || true
pkg install -y termux-x11-nightly virglrenderer-android pulseaudio

# ── 2. Check Termux:X11 Android App ─────────────────────────────────────────
header "2/3  Checking Termux:X11 Android Application"
if pm list packages 2>/dev/null | grep -q "com.termux.x11"; then
    info "Termux:X11 Android app is installed ✓"
else
    echo ""
    echo -e "${YELLOW}${BOLD}┌──────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}${BOLD}│  ℹ  Please ensure Termux:X11 APK is installed                │${NC}"
    echo -e "${YELLOW}${BOLD}│  Download from: https://github.com/termux/termux-x11/releases│${NC}"
    echo -e "${YELLOW}${BOLD}└──────────────────────────────────────────────────────────────┘${NC}"
    echo ""
fi

# ── 3. Install GUI & Mesa GPU Drivers in PRoot ──────────────────────────────
header "3/3  Installing Desktop packages & Mesa VirGL in PRoot"

proot-distro login ubuntu --shared-tmp -- bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive

apt-get update -qq

# --- Desktop & Window Manager ---
DE_PKGS=(
    openbox
    tint2
    pcmanfm
    lxterminal
    xterm
    x11-xserver-utils
    x11-utils
    xdg-utils
    dbus-x11
    fonts-dejavu-core
    fonts-liberation
    fonts-noto-core
    fontconfig
)

echo '[+] Installing Openbox, Tint2, PCManFM & fonts...'
apt-get install -y -qq \"\${DE_PKGS[@]}\" 2>&1 | tail -n 5

# --- Mesa Gallium VirGL Drivers ---
GL_PKGS=(
    mesa-utils
    mesa-utils-bin
    libgl1-mesa-dri
    mesa-libgallium
    libegl-mesa0
    libgbm1
    libgl1
    libgles2
    libglx-mesa0
    mesa-vulkan-drivers
)

echo '[+] Installing Mesa Gallium & OpenGL drivers (VirGL virpipe)...'
apt-get install -y -qq \"\${GL_PKGS[@]}\" 2>&1 | tail -n 5

# --- Configure Environment in PRoot ---
BASHRC=\"/root/.bashrc\"
MARKER=\"# PRoot X11 Desktop — VirGL GPU environment\"
END_MARKER=\"# END PRoot X11 Desktop\"

if grep -qF \"\$MARKER\" \"\$BASHRC\" 2>/dev/null; then
    sed -i \"/\$MARKER/,/\$END_MARKER/d\" \"\$BASHRC\"
fi

cat >> \"\$BASHRC\" << 'EOF'

# PRoot X11 Desktop — VirGL GPU environment
export DISPLAY=:0
export GALLIUM_DRIVER=virpipe
export MESA_GL_VERSION_OVERRIDE=4.0
export MESA_GLES_VERSION_OVERRIDE=3.0
export LIBGL_ALWAYS_SOFTWARE=0
# END PRoot X11 Desktop
EOF
"

# ── Setup Complete ───────────────────────────────────────────────────────────
header "Desktop Setup Complete!"

echo -e "  ${GREEN}${BOLD}✓ Termux:X11 environment configured${NC}"
echo -e "  ${GREEN}${BOLD}✓ Openbox, Tint2, PCManFM & VirGL GPU installed in PRoot${NC}"
echo ""
echo -e "  ${BOLD}To start the local desktop:${NC}"
echo -e "    ${CYAN}./start_desktop.sh${NC}"
echo ""
