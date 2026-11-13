#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    echo "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

# Detect the Google Drive remote by its type ('drive'), so the folder and
# mount source follow whatever name you gave it in `rclone config`.
detect_remote() {
    rclone listremotes --long 2>/dev/null \
        | awk 'tolower($NF)=="drive"{sub(/:$/,"",$1); print $1; exit}'
}

echo "==> Detecting Google Drive remote from rclone config..."
REMOTE_NAME="$(detect_remote)"
if [ -z "${REMOTE_NAME}" ]; then
    echo ""
    echo "No remote of type 'drive' was found in your rclone config."
    echo "In 'rclone config': choose 'New remote', pick any name, select"
    echo "'Google Drive' (type: drive), and follow the web login."
    echo ""
    read -rp "Do you want to run 'rclone config' now? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        rclone config
        REMOTE_NAME="$(detect_remote)"
    fi
fi
if [ -z "${REMOTE_NAME}" ]; then
    echo "Error: no Google Drive remote available. Exiting." >&2
    exit 1
fi
echo "==> Using Google Drive remote: ${REMOTE_NAME}"

MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
SERVICE_DIR="${HOME}/.config/systemd/user"
# Service name stays fixed regardless of the remote name.
SERVICE_FILE="${SERVICE_DIR}/rclone-gdrive.service"

echo "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

echo "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

echo "==> Unmounting existing Google Drive mount if present..."
fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

echo "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=RClone Google Drive Mount Service
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

echo "==> Enabling and starting rclone-gdrive.service..."
systemctl --user enable --now rclone-gdrive.service

echo "==> Checking service status..."
systemctl --user status rclone-gdrive.service --no-pager

echo ""
echo "==> Setup complete! Your Google Drive is mounted at ${MOUNT_DIR}"
