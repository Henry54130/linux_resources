#!/usr/bin/env bash
set -euo pipefail

echo "==> Updating package index..."
sudo apt update

echo "==> Installing rclone and fuse3..."
sudo apt install -y rclone fuse3

echo "==> Checking installation..."
rclone version

echo "==> rclone and fuse3 installed successfully!"
echo "If you have not configured OneDrive yet, run: rclone config"
