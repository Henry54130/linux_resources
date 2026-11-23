#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$script_dir/lib/log.sh"

log "==> Checking if rclone is installed..."
if ! command -v rclone &>/dev/null; then
    log "Error: rclone is not installed. Please install it first (e.g., ./install-rclone.sh)."
    exit 1
fi

# Detect EVERY OneDrive remote by its type ('onedrive'). Each remote — whatever
# name you gave it in `rclone config` — gets its own mount dir (~/rclone/<name>)
# and its own systemd service (rclone-<name>.service), so multiple OneDrive
# accounts can be mounted side by side without clobbering each other.
detect_remotes() {
    rclone listremotes --long 2>/dev/null \
        | awk 'tolower($NF)=="onedrive"{sub(/:$/,"",$1); print $1}'
}

log "==> Detecting OneDrive remote(s) from rclone config..."
mapfile -t REMOTES < <(detect_remotes)
if [ "${#REMOTES[@]}" -eq 0 ]; then
    echo ""
    echo "No remote of type 'onedrive' was found in your rclone config."
    echo "In 'rclone config': choose 'New remote', pick any name, select"
    echo "'Microsoft OneDrive' (type: onedrive), and follow the web login."
    echo ""
    read -rp "Do you want to run 'rclone config' now? (y/N): " choice
    if [[ "$choice" =~ ^[Yy]$ ]]; then
        rclone config
        mapfile -t REMOTES < <(detect_remotes)
    fi
fi
if [ "${#REMOTES[@]}" -eq 0 ]; then
    log "Error: no OneDrive remote available. Exiting."
    exit 1
fi
log "==> Found ${#REMOTES[@]} OneDrive remote(s): ${REMOTES[*]}"

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
Description=RClone OneDrive Mount Service (${REMOTE_NAME})
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
log "==> Setup complete! Mounted ${#REMOTES[@]} OneDrive remote(s) under ~/rclone/"
log "==> Full run log + diagnostics saved to: ${LOG_FILE}"
log "==> If something looks wrong, just paste the contents of that file."
