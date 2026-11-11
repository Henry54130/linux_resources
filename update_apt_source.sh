#!/bin/bash
set -e

echo "==> Updating Ubuntu mirrors to Taiwan archive..."
if [ -f /etc/apt/sources.list.d/official-package-repositories.list ]; then
    sudo sed -i 's|http://.*archive.ubuntu.com/ubuntu|http://tw.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list.d/official-package-repositories.list
    sudo sed -i 's|http://ftp.ntu.edu.tw/ubuntu|http://tw.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list.d/official-package-repositories.list
    sudo sed -i 's|http://ftp.ntu.edu.tw/linux/ubuntu|http://tw.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list.d/official-package-repositories.list
fi

echo "==> Fixing i386 architecture warnings for third-party repositories..."

# Function to fix arch=amd64 for a specific repo list file
fix_repo_arch() {
    local file="$1"
    local name="$2"

    if [ -f "$file" ]; then
        echo "    -> Updating $name repository mirror configuration ($file)..."
        # If [signed-by=...] exists, insert arch=amd64
        sudo sed -i 's|deb \[signed-by|deb [arch=amd64 signed-by|g' "$file"
        # If no brackets exist, add [arch=amd64]
        sudo sed -i 's|^deb https://|deb [arch=amd64] https://|g' "$file"
        sudo sed -i 's|^deb http://|deb [arch=amd64] http://|g' "$file"
    fi
}

# Apply arch fix specifically to Brave and VSCodium
fix_repo_arch "/etc/apt/sources.list.d/brave-browser-release.list" "Brave Browser"
fix_repo_arch "/etc/apt/sources.list.d/vscodium.list" "VSCodium"

echo "==> Running apt update..."
sudo apt update

echo "==> Done!"
