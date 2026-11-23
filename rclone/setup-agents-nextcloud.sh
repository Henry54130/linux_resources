#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$script_dir/lib/log.sh"

log "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    log "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

# Fixed name, not auto-detected by backend type: a personal Nextcloud remote
# (setup-personal-nextcloud.sh) is also type 'webdav', so picking by type would
# be ambiguous once both exist. This remote is what docker bind-mounts into
# the agent container, so the name must stay exactly 'agents-nextcloud'.
REMOTE_NAME="agents-nextcloud"

log "==> Checking for existing rclone remote '${REMOTE_NAME}'..."
if ! rclone listremotes 2>/dev/null | grep -qx "${REMOTE_NAME}:"; then
    echo ""
    echo "No '${REMOTE_NAME}' remote found. Let's set it up."
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
fi
log "==> Using remote: ${REMOTE_NAME}"

MOUNT_DIR="${HOME}/rclone/${REMOTE_NAME}"
# Must match the container user (node=1000) so the docker bind-mount of this
# FUSE mount is readable inside the container.
MOUNT_UID=1000
MOUNT_GID=1000
SERVICE_DIR="${HOME}/.config/systemd/user"
SERVICE_NAME="agents-nextcloud-mount.service"
SERVICE_FILE="${SERVICE_DIR}/${SERVICE_NAME}"

log "==> Creating mount directory at ${MOUNT_DIR}..."
mkdir -p "${MOUNT_DIR}"

log "==> Creating systemd user service directory..."
mkdir -p "${SERVICE_DIR}"

log "==> Unmounting existing mount if present..."
fusermount3 -u "${MOUNT_DIR}" 2>/dev/null || fusermount -u "${MOUNT_DIR}" 2>/dev/null || true

# fuse user_allow_other: dockerd reads this FUSE mount as root to bind-mount it
# into the agent container, and FUSE blocks even root by default. allow_root
# would be the minimal-exposure option, but rclone's mount has dropped support
# for it upstream (bazil/fuse#144) — it's silently ignored — so allow_other is
# the only flag that actually works, despite opening the mount to all host users.
if ! grep -qE '^\s*user_allow_other' /etc/fuse.conf 2>/dev/null; then
    log "==> /etc/fuse.conf missing user_allow_other (required for docker to read this mount). Adding (may prompt for sudo password)..."
    if echo 'user_allow_other' | sudo tee -a /etc/fuse.conf >/dev/null; then
        log "    Added."
    else
        log "    [action needed] run once: echo user_allow_other | sudo tee -a /etc/fuse.conf"
    fi
fi

log "==> Creating systemd service file at ${SERVICE_FILE}..."
cat << EOF > "${SERVICE_FILE}"
[Unit]
Description=RClone Agent Nextcloud Mount Service
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount ${REMOTE_NAME}: %h/rclone/${REMOTE_NAME} \\
  --config=%h/.config/rclone/rclone.conf \\
  --allow-other --uid ${MOUNT_UID} --gid ${MOUNT_GID} --umask 0022 \\
  --vfs-cache-mode writes \\
  --dir-cache-time 10s
ExecStop=/bin/fusermount3 -u %h/rclone/${REMOTE_NAME}
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF

log "==> Enabling linger so the mount starts at boot (no desktop login needed)..."
if loginctl show-user "$USER" 2>/dev/null | grep -q "Linger=yes"; then
    log "    Linger already enabled for ${USER}."
elif sudo loginctl enable-linger "$USER"; then
    log "    Linger enabled for ${USER}."
else
    log "    [action needed] run once to mount on boot without login:"
    log "        sudo loginctl enable-linger $USER"
fi

log "==> Reloading systemd user daemon..."
systemctl --user daemon-reload

log "==> Enabling and starting ${SERVICE_NAME}..."
systemctl --user enable --now "${SERVICE_NAME}"

log "==> Capturing diagnostics snapshot for debugging..."
{
    echo "---- systemctl status ----"
    systemctl --user status "${SERVICE_NAME}" --no-pager || true
    echo "---- journalctl (last 30 lines) ----"
    journalctl --user -u "${SERVICE_NAME}" -n 30 --no-pager -l || true
    echo "---- /etc/fuse.conf ----"
    grep -E 'allow_other' /etc/fuse.conf 2>/dev/null || echo "(user_allow_other not found)"
    echo "---- mount check ----"
    mountpoint "${MOUNT_DIR}" 2>&1 || true
    echo "---- dir listing (first 20) ----"
    ls -la "${MOUNT_DIR}" 2>&1 | head -20 || true
} 2>&1 | tee -a "$LOG_FILE"

log ""
log "==> Setup complete! Agent Nextcloud mounted at ${MOUNT_DIR}"
log "==> Full run log + diagnostics saved to: ${LOG_FILE}"
log "==> If something looks wrong, just paste the contents of that file."
