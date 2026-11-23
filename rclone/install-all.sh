#!/usr/bin/env bash
set -uo pipefail
# Deliberately no `-e`: one setup script failing (e.g. a remote that still
# needs `rclone config`) shouldn't stop the rest from running.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$script_dir/lib/log.sh"

log "==> Checking rclone + fuse3..."
if ! command -v rclone &>/dev/null || ! command -v fusermount3 &>/dev/null; then
    log "    Not found, running install-rclone.sh (may prompt for sudo password)..."
    "$script_dir/install-rclone.sh" 2>&1 | tee -a "$LOG_FILE"
else
    log "    Already installed, skipping."
fi

setup_scripts=(
    setup-onedrive.sh
    setup-google-drive.sh
    setup-personal-nextcloud.sh
    setup-agents-nextcloud.sh
)

declare -A results
for s in "${setup_scripts[@]}"; do
    log ""
    log "==> Running ${s}..."
    if "$script_dir/${s}"; then
        results["$s"]="ok"
    else
        results["$s"]="failed (exit $?)"
    fi
done

log ""
log "==> Running check-all.sh for a final summary..."
"$script_dir/check-all.sh" || true

log ""
log "==> install-all summary:"
for s in "${setup_scripts[@]}"; do
    log "    ${s}: ${results[$s]}"
done
log "==> Each script above also wrote its own detailed log under ${LOG_DIR}/"
log "==> This run's orchestration log: ${LOG_FILE}"
