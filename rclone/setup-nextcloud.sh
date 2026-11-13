#!/usr/bin/env bash
set -euo pipefail

echo "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    echo "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

# Detect an existing Nextcloud (webdav) remote by its type, so the folder and
# mount source follow whatever name you gave it in `rclone config`.
echo "==> Detecting Nextcloud remote from rclone config..."
REMOTE_NAME="$(rclone listremotes --long 2>/dev/null \
    | awk 'tolower($NF)=="webdav"{sub(/:$/,"",$1); print $1; exit}')"

if [ -z "${REMOTE_NAME}" ]; then
    # None found: create one. We name it 'nextcloud' here, and the folder
    # and service below will follow that name.
    REMOTE_NAME="nextcloud"
    echo ""
    echo "No webdav remote was found. Let's set up '${REMOTE_NAME}'."
    echo "(If you have 2FA enabled, create an app password first under"
    echo "Nextcloud Settings > Security, and paste that in below instead"
    echo "of your login password.)"
    echo ""
    read -rp "Nextcloud URL (e.g. https://cloud.example.com): " nc_url
    nc_url="${nc_url%/}"
    read -rp "Nextcloud username: " nc_user
    read -rsp "Nextcloud password (or app password): " nc_password
    echo ""

    echo "==> Creating rclone remote '${REMOTE_NAME}'..."
    rclone config create "${REMOTE_NAME}" webdav \
        url "${nc_url}/remote.php/dav/files/${nc_user}/" \
        vendor nextcloud \
        user "${nc_user}" \
        pass "${nc_password}" \
        --obscure
    unset nc_password
fi
echo "==> Using Nextcloud remote: ${REMOTE_NAME}"

MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
SERVICE_DIR="${HOME}/.config/systemd/user"
# Service name stays fixed regardless of the remote name.
SERVICE_FILE="${SERVICE_DIR}/rclone-nextcloud.service"

echo "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

echo "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

echo "==> Unmounting existing Nextcloud mount if present..."
fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

echo "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=RClone Nextcloud Mount Service
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

echo "==> Enabling and starting rclone-nextcloud.service..."
systemctl --user enable --now rclone-nextcloud.service

echo "==> Checking service status..."
systemctl --user status rclone-nextcloud.service --no-pager

echo ""
echo "==> Setup complete! Your Nextcloud is mounted at ${MOUNT_DIR}"
