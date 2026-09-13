#!/usr/bin/env bash
set -euo pipefail

MOUNT_DIR="${HOME}/OneDrive"
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_FILE="${SERVICE_DIR}/rclone-onedrive.service"

echo "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

echo "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

echo "==> Unmounting existing OneDrive mount if present..."
fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

echo "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << 'EOF' > "${SERVICE_FILE}"
[Unit]
Description=RClone OneDrive Mount Service
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount onedrive: %h/OneDrive \
  --config=%h/.config/rclone/rclone.conf \
  --vfs-cache-mode writes \
  --vfs-cache-max-size 10G \
  --dir-cache-time 72h \
  --vfs-read-chunk-size 32M
ExecStop=/bin/fusermount -u %h/OneDrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

echo "==> Reloading systemd user daemon..."
systemctl --user daemon-reload

echo "==> Enabling and starting rclone-onedrive.service..."
systemctl --user enable --now rclone-onedrive.service

echo "==> Checking service status..."
systemctl --user status rclone-onedrive.service --no-pager

echo ""
echo "==> Setup complete! Your OneDrive is mounted at ${MOUNT_DIR}"
