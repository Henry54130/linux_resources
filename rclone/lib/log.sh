# Shared logger for rclone/*.sh. Source after `set -euo pipefail`:
#   script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
#   . "$script_dir/lib/log.sh"
#
# Each run gets its own {project}/rclone/logs/{timestamp}.log (never
# overwritten), so past runs stay around for comparison instead of
# clobbering each other. This is the repo's own logs/ dir (gitignored),
# not ~/rclone/ — that's the unrelated mount-point base dir.
# log() writes to both stdout and that file, so the full trace + diagnostics
# end up in one file that's easy to cat and paste for debugging.

_log_lib_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname -- "$_log_lib_dir")/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date '+%Y%m%d-%H%M%S').log"

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_FILE"; }

log "==> $(basename "$0") started"
