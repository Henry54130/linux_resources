#!/data/data/com.termux/files/usr/bin/bash
###############################################################################
#  setup_linux.sh — Install & Provision Basic Headless PRoot Linux in Termux
#
#  Run this in TERMUX.
#  It configures Termux storage, installs proot-distro (Ubuntu), updates apt,
#  sets up timezone/locales, and installs essential headless tools.
###############################################################################
set -e

# ── Colors & helpers ─────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[✗]${NC} $*"; }
header(){ echo -e "\n${CYAN}${BOLD}═══ $* ═══${NC}\n"; }

header "PRoot Linux (Ubuntu) Headless Setup"

# ── 1. Setup Termux Storage ──────────────────────────────────────────────────
header "1/5  Checking Termux storage access"
if [ ! -d "$HOME/storage" ]; then
    info "Requesting Android storage permission..."
    termux-setup-storage || true
    sleep 2
else
    info "Termux storage already configured ✓"
fi

# ── 2. Update Termux & Install Base Packages ─────────────────────────────────
header "2/5  Installing Termux host packages"
pkg update -y
pkg install -y proot-distro openssh curl wget tar xz-utils git htop pulseaudio

# ── 3. Install PRoot Ubuntu Distro ───────────────────────────────────────────
header "3/5  Installing Ubuntu via proot-distro"
if proot-distro list | grep -q "ubuntu.*\[installed\]"; then
    info "Ubuntu is already installed in proot-distro ✓"
else
    info "Downloading and installing Ubuntu rootfs..."
    proot-distro install ubuntu
fi

# ── 4. Provision PRoot Linux Headless System ────────────────────────────────
header "4/5  Provisioning Ubuntu headless environment"

info "Updating Ubuntu packages and installing CLI essentials..."
proot-distro login ubuntu -- bash -c "
set -e
export DEBIAN_FRONTEND=noninteractive

# Update package lists
apt-get update -qq
apt-get upgrade -y -qq

# Essential headless CLI tools
APT_PACKAGES=(
    curl
    wget
    git
    htop
    nano
    vim
    sudo
    ca-certificates
    gnupg
    locales
    tzdata
    iproute2
    net-tools
    dnsutils
    software-properties-common
    build-essential
    dbus
    procps
    unzip
    zip
)

echo '[+] Installing core CLI packages...'
apt-get install -y -qq \"\${APT_PACKAGES[@]}\" 2>&1 | tail -n 5

# Configure Locale (UTF-8)
if ! locale -a | grep -qi 'en_US.utf8'; then
    locale-gen en_US.UTF-8 >/dev/null 2>&1 || true
    update-locale LANG=en_US.UTF-8 >/dev/null 2>&1 || true
fi

# Ensure DNS is set up
if [ ! -s /etc/resolv.conf ]; then
    echo 'nameserver 1.1.1.1' > /etc/resolv.conf
    echo 'nameserver 8.8.8.8' >> /etc/resolv.conf
fi

# Configure .bashrc prompt & aliases
BASHRC=\"/root/.bashrc\"
if ! grep -q \"PROOT_HEADLESS_CONFIG\" \"\$BASHRC\" 2>/dev/null; then
cat >> \"\$BASHRC\" << 'EOF'

# PROOT_HEADLESS_CONFIG
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
alias ll='ls -la --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
# END PROOT_HEADLESS_CONFIG
EOF
fi
"

# ── 5. Setup Complete ────────────────────────────────────────────────────────
header "5/5  Headless Setup Complete!"

echo -e "  ${GREEN}${BOLD}✓ Ubuntu 24.04+ (PRoot) is ready for headless use!${NC}"
echo ""
echo -e "  ${BOLD}To enter your Linux terminal:${NC}"
echo -e "    ${CYAN}proot-distro login ubuntu${NC}"
echo ""
echo -e "  ${BOLD}Next steps for GUI:${NC}"
echo -e "    • To install local X11 desktop (Termux:X11): ${CYAN}./setup_desktop.sh${NC}"
echo -e "    • To install VNC desktop (TigerVNC)       : ${CYAN}./setup_vnc.sh${NC}"
echo ""
