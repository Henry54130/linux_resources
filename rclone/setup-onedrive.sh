#!/usr/bin/env bash
set -euo pipefail

# Detect the OneDrive remote by its type (not its name), so the folder and
# mount source follow whatever name you gave it in `rclone config`.
echo "==> Detecting OneDrive remote from rclone config..."
REMOTE_NAME="$(rclone listremotes --long 2>/dev/null \
  | awk 'tolower($NF)=="onedrive"{sub(/:$/,"",$1); print $1; exit}')"

if [ -z "${REMOTE_NAME}" ]; then
  echo "ERROR: No remote of type 'onedrive' found in your rclone config." >&2
  echo "       Run 'rclone config' to create one first." >&2
  exit 1
fi
echo "==> Using OneDrive remote: ${REMOTE_NAME}"

MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
SERVICE_DIR="${HOME}/.config/systemd/user"
# Service name stays fixed regardless of the remote name.
SERVICE_FILE="${SERVICE_DIR}/rclone-onedrive.service"

echo "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

echo "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

echo "==> Unmounting existing OneDrive mount if present..."
fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

echo "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=RClone OneDrive Mount Service
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount ${REMOTE_NAME}: %h/rclone/${REMOTE_NAME} \\
  --config=%h/.config/rclone/rclone.conf \\
  --vfs-cache-mode writes \\
  --vfs-cache-max-size 10G \\
  --dir-cache-time 72h \\
  --vfs-read-chunk-size 32M
ExecStop=/bin/fusermount -u %h/rclone/${REMOTE_NAME}
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
