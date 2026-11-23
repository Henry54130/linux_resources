#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
. "$script_dir/lib/log.sh"

# Sanity-checks every rclone mount under ~/rclone: is it actually mounted,
# and does it have real content two levels down (not just an empty/stale dir)?
BASE_DIR="${RCLONE_BATCH_BASE_DIR:-${HOME}/rclone}"
log "==> Checking mounts under ${BASE_DIR}"

if [[ ! -d "$BASE_DIR" ]]; then
    log "${BASE_DIR} does not exist — nothing mounted yet."
    exit 0
fi

shopt -s nullglob
remote_dirs=("$BASE_DIR"/*/)
shopt -u nullglob

if [[ ${#remote_dirs[@]} -eq 0 ]]; then
    log "${BASE_DIR} is empty — no remotes mounted."
    exit 0
fi

for remote_dir in "${remote_dirs[@]}"; do
    remote_dir="${remote_dir%/}"
    remote="$(basename "$remote_dir")"
    [[ "$remote" == "logs" ]] && continue

    log "---- ${remote} ----"
    if mountpoint -q "$remote_dir"; then
        log "    mounted: yes"
    else
        log "    mounted: no (plain directory, not a live FUSE mount)"
    fi

    {
        echo "  ls -la ${remote_dir}:"
        ls -la "$remote_dir"
        echo "  two levels down (first 20):"
        find "$remote_dir" -mindepth 2 -maxdepth 2 2>/dev/null | head -20
    } | tee -a "$LOG_FILE"

    depth2_count="$(find "$remote_dir" -mindepth 2 -maxdepth 2 2>/dev/null | wc -l)"
    if [[ "$depth2_count" -eq 0 ]]; then
        log "    [empty] nothing found two levels down under ${remote}."
    else
        log "    ${depth2_count} entries found two levels down under ${remote}."
    fi
    echo
done

log "==> Full report saved to: ${LOG_FILE}"
