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
if ! rclone listremotes | grep -qi "^${REMOTE_NAME}:"; then
    echo ""
    echo "Remote '${REMOTE_NAME}:' was not found. Let's set it up."
    echo "This exchanges your Nextcloud account password for a dedicated app"
    echo "password (via Nextcloud's getapppassword API) — your main password is"
    echo "used once, right here, and is never written to disk."
    echo ""
    read -rp "Nextcloud URL (e.g. https://cloud.example.com): " nc_url
    nc_url="${nc_url%/}"
    read -rp "Nextcloud username: " nc_user
    read -rsp "Nextcloud account password (used once, not stored): " nc_password
    echo ""

    device_label="rclone_$(hostname -s 2>/dev/null || hostname)_${nc_user}"
    device_label="${device_label//[^A-Za-z0-9._-]/_}"

    echo "==> Requesting app password '${device_label}' from ${nc_url}..."
    api_response="$(curl -fsS -u "${nc_user}:${nc_password}" \
        -H "OCS-APIREQUEST: true" \
        -H "User-Agent: ${device_label}" \
        "${nc_url}/ocs/v2.php/core/getapppassword?format=json")" || {
        echo "Error: Failed to reach ${nc_url} or credentials were rejected." >&2
        echo "(If your account has 2FA enabled, create an app password manually" >&2
        echo "under Nextcloud Settings > Security instead.)" >&2
        unset nc_password
        exit 1
    }
    unset nc_password

    app_password="$(printf '%s' "$api_response" | python3 -c '
import json, sys
try:
    print(json.load(sys.stdin)["ocs"]["data"]["apppassword"])
except Exception:
    sys.exit(1)
')" || {
        echo "Error: Could not parse an app password out of the server response." >&2
        echo "Response was: ${api_response}" >&2
        exit 1
    }

    echo "==> Creating rclone remote '${REMOTE_NAME}'..."
    rclone config create "${REMOTE_NAME}" webdav \
        url "${nc_url}/remote.php/dav/files/${nc_user}/" \
        vendor nextcloud \
        user "${nc_user}" \
        pass "${app_password}" \
        --obscure
    unset app_password

    echo "==> Done. A new app password named '${device_label}' was created —"
    echo "    review/revoke it anytime under Nextcloud Settings > Security > Devices & Sessions."
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
