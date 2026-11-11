#!/usr/bin/env bash
set -euo pipefail

REMOTE_NAME="nextcloud"
MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/rclone-nextcloud.service"

echo "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    echo "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

echo "==> Checking if '${REMOTE_NAME}' remote exists in rclone..."
if ! rclone listremotes | grep -q "^${REMOTE_NAME}:"; then
    echo ""
    echo "Warning: Remote '${REMOTE_NAME}:' was not found in your rclone config."
    echo "Please configure it by running:"
    echo "    rclone config"
    echo "Choose 'New remote', name it '${REMOTE_NAME}', select 'WebDAV' (type: webdav),"
    echo "set vendor to 'nextcloud', then enter your Nextcloud server URL"
    echo "(e.g. https://your-domain/remote.php/dav/files/USERNAME/), username and password."
    echo ""
    read -rp "Do you want to run 'rclone config' now? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        rclone config
    else
        echo "Exiting. Please configure '${REMOTE_NAME}' first."
        exit 1
    fi
fi

echo "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

echo "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

echo "==> Unmounting existing Nextcloud mount if present..."
fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

echo "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << 'EOF' > "${SERVICE_FILE}"
[Unit]
Description=RClone Nextcloud Mount Service
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount nextcloud: %h/rclone/nextcloud \
  --config=%h/.config/rclone/rclone.conf \
  --vfs-cache-mode writes \
  --vfs-cache-max-size 10G \
  --dir-cache-time 72h \
  --vfs-read-chunk-size 32M
ExecStop=/bin/fusermount -u %h/rclone/nextcloud
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "==> Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "==> Enabling and starting rclone-nextcloud.service..."
systemctl --user enable --now rclone-nextcloud.service

echo "==> Checking service status..."
systemctl --user status rclone-nextcloud.service --no-pager

echo ""
echo "==> Setup complete! Your Nextcloud is mounted at ${MOUNT_DIR}"
