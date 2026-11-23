#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$script_dir/lib/log.sh"

log "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    log "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

# Detect EVERY personal Nextcloud remote by its type ('webdav'). Each remote gets
# its own mount dir (~/rclone/<name>) and its own systemd service
# (rclone-<name>.service), so multiple Nextcloud accounts can coexist.
# 'agents-nextcloud' is also a webdav remote but is managed by
# setup-agents-nextcloud.sh (it needs --allow-other for docker), so exclude it
# here to avoid building a second, conflicting mount on the same mountpoint.
detect_remotes() {
    rclone listremotes --long 2>/dev/null \
        | awk 'tolower($NF)=="webdav" && $1!="agents-nextcloud:"{sub(/:$/,"",$1); print $1}'
}

log "==> Detecting Nextcloud remote(s) from rclone config..."
mapfile -t REMOTES < <(detect_remotes)
if [ "${#REMOTES[@]}" -eq 0 ]; then
    # None found: create one. We name it 'nextcloud' here, and its folder
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

    log "==> Creating rclone remote '${REMOTE_NAME}'..."
    rclone config create "${REMOTE_NAME}" webdav \
        url "${nc_url}/remote.php/dav/files/${nc_user}/" \
        vendor nextcloud \
        user "${nc_user}" \
        pass "${nc_password}" \
        --obscure 2>&1 | tee -a "$LOG_FILE"
    unset nc_password
    mapfile -t REMOTES < <(detect_remotes)
fi
if [ "${#REMOTES[@]}" -eq 0 ]; then
    log "Error: no Nextcloud remote available. Exiting."
    exit 1
fi
log "==> Found ${#REMOTES[@]} Nextcloud remote(s): ${REMOTES[*]}"

SERVICE_DIR="${HOME}/.config/systemd/user"
log "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

# Linger is a per-user setting, so enable it once rather than per-remote.
log "==> Enabling linger so the mounts start at boot (no desktop login needed)..."
if loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
    log "    Linger already enabled for ${USER}."
elif sudo loginctl enable-linger "$USER"; then
    log "    Linger enabled for ${USER}."
else
    log "    [action needed] run once to mount on boot without login:"
    log "        sudo loginctl enable-linger $USER"
fi

# One service file per remote.
for REMOTE_NAME in "${REMOTES[@]}"; do
    MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
    SERVICE_FILE="${SERVICE_DIR}/rclone-${REMOTE_NAME}.service"

    log ""
    log "==> [${REMOTE_NAME}] Creating mount directory at ${MOUNT_DIR}..."
    mkdir -p "${MOUNT_DIR}"

    log "==> [${REMOTE_NAME}] Unmounting existing mount if present..."
    fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

    log "==> [${REMOTE_NAME}] Writing systemd service file at ${SERVICE_FILE}..."
    cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=RClone Nextcloud Mount Service (${REMOTE_NAME})
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
done

log "==> Reloading systemd user daemon..."
systemctl --user daemon-reload

# Enable + start each service, then capture a per-remote diagnostics snapshot.
for REMOTE_NAME in "${REMOTES[@]}"; do
    MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
    SERVICE_NAME="rclone-${REMOTE_NAME}.service"

    log ""
    log "==> Enabling and starting ${SERVICE_NAME}..."
    systemctl --user enable --now "${SERVICE_NAME}"

    log "==> [${REMOTE_NAME}] Capturing diagnostics snapshot for debugging..."
    {
        echo "---- systemctl status ${SERVICE_NAME} ----"
        systemctl --user status "${SERVICE_NAME}" --no-pager || true
        echo "---- journalctl (last 30 lines) ----"
        journalctl --user -u "${SERVICE_NAME}" -n 30 --no-pager -l || true
        echo "---- mount check ----"
        mountpoint "${MOUNT_DIR}" 2>&1 || true
        echo "---- dir listing (first 20) ----"
        ls -la "${MOUNT_DIR}" 2>&1 | head -20 || true
    } 2>&1 | tee -a "$LOG_FILE"
done

log ""
log "==> Setup complete! Mounted ${#REMOTES[@]} Nextcloud remote(s) under ~/rclone/"
log "==> Full run log + diagnostics saved to: ${LOG_FILE}"
log "==> If something looks wrong, just paste the contents of that file."
